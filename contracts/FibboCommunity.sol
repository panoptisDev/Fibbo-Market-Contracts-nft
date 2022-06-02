// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IFibboVerification {
    function checkIfVerified(address) external view returns (bool);
}

contract FibboCommunity is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public suggestionsIds;
    Counters.Counter public finishedSuggestionsCount;
    Counters.Counter public withdrawedSuggestionsCount;

    uint16 public proposerFee;

    mapping(uint256 => Suggestion) public suggestions;
    mapping(uint256 => uint256) public suggestionsProgress;
    mapping(uint256 => FinishedSuggestion) public finishedSuggestions;
    mapping(uint256 => WithdrawedSuggestion) public withdrawedSuggestions;

    IFibboVerification public fibboVerification;

    struct Suggestion {
        uint256 suggestionId;
        address payable proposer;
        uint256 totalAmount;
        string title;
        string description;
    }

    struct SuggestionInProgress {
        uint256 suggestionId;
        address payable proposer;
        string title;
        string description;
        uint256 totalAmount;
        uint256 progress;
    }

    struct FinishedSuggestion {
        uint256 suggestionId;
        uint256 finishedFor;
        string title;
    }

    struct WithdrawedSuggestion {
        uint256 suggestionId;
        uint256 finishedSuggestionId;
        uint256 widthdrawedFor;
    }

    event AmmountAdded(
        uint256 amount,
        uint256 suggestionId,
        Suggestion suggestion
    );

    event SuggestionCreated(uint256 suggestionId, Suggestion suggestion);

    event SuggestionCompleted(uint256 suggestionId, Suggestion suggestion);

    /// @notice Contract initializer
    constructor(uint16 _proposerFee) {
        proposerFee = _proposerFee;
    }

    modifier suggestionExists(uint256 _suggestionId) {
        Suggestion memory _suggestion = suggestions[_suggestionId];
        require(
            _suggestion.proposer != address(0),
            "Suggestion does not exist!"
        );

        _;
    }

    modifier suggestionFinished(uint256 _suggestionId) {
        Suggestion memory _suggestion = suggestions[_suggestionId];
        uint256 progress = suggestionsProgress[_suggestionId];
        require(
            progress >= _suggestion.totalAmount,
            "Suggestion has not reached the total amount!"
        );

        _;
    }

    modifier suggestionInProgress(uint256 _suggestionId) {
        Suggestion memory _suggestion = suggestions[_suggestionId];
        uint256 progress = suggestionsProgress[_suggestionId];
        require(
            progress < _suggestion.totalAmount,
            "Suggestion has reached the total amount!"
        );

        _;
    }

    function createSuggestion(
        string memory _title,
        string memory _desc,
        uint256 _totalAmount,
        address proposer
    ) external onlyOwner {
        require(_totalAmount > 10, "Total amount must be higher than 10!");
        require(proposer != address(0), "Address proposer is not valid");

        bool isVerifiedAddress = fibboVerification.checkIfVerified(proposer);
        require(isVerifiedAddress, "Address is not verified!");

        suggestionsIds.increment();

        uint256 newSuggestionId = suggestionsIds.current();

        suggestions[newSuggestionId] = Suggestion(
            newSuggestionId,
            payable(proposer),
            _totalAmount,
            _title,
            _desc
        );

        emit SuggestionCreated(newSuggestionId, suggestions[newSuggestionId]);
    }

    function addTokensToSuggestion(uint256 _suggestionId)
        external
        payable
        suggestionExists(_suggestionId)
        suggestionInProgress(_suggestionId)
    {
        Suggestion memory _sugg = suggestions[_suggestionId];
        uint256 progress = suggestionsProgress[_suggestionId];

        bool isVerifiedArtist = fibboVerification.checkIfVerified(msg.sender);

        require(isVerifiedArtist, "Sender is not a verified address!");

        uint256 newProgress = progress + msg.value;

        suggestionsProgress[_suggestionId] = newProgress;

        if (newProgress >= _sugg.totalAmount) {
            finishedSuggestionsCount.increment();
            uint256 newFinishedCount = finishedSuggestionsCount.current();

            finishedSuggestions[newFinishedCount] = FinishedSuggestion(
                _suggestionId,
                newProgress,
                _sugg.title
            );
        }
    }

    function withdrawFromSuggestion(
        uint256 _suggestionId,
        uint256 _finishedSuggestionId
    )
        external
        payable
        suggestionExists(_suggestionId)
        suggestionFinished(_suggestionId)
        onlyOwner
    {
        Suggestion memory suggestion = suggestions[_suggestionId];

        address payable _proposer = suggestion.proposer;

        uint256 totalInSuggestion = suggestionsProgress[_suggestionId];

        uint256 feeAmount = (totalInSuggestion * proposerFee) / 10000;

        _proposer.transfer(feeAmount);

        payable(msg.sender).transfer(totalInSuggestion - feeAmount);

        withdrawedSuggestionsCount.increment();

        uint256 newWithdrawedCount = withdrawedSuggestionsCount.current();

        withdrawedSuggestions[newWithdrawedCount] = WithdrawedSuggestion(
            _suggestionId,
            _finishedSuggestionId,
            totalInSuggestion
        );
    }

    function getInProgressSuggestions()
        public
        view
        returns (SuggestionInProgress[] memory)
    {
        uint256 suggestionsCount = suggestionsIds.current();
        uint256 finishedCount = finishedSuggestionsCount.current();
        uint256 currentIndex = 0;
        uint256 suggestionsInProgressCount = suggestionsCount - finishedCount;

        SuggestionInProgress[] memory result = new SuggestionInProgress[](
            suggestionsInProgressCount
        );

        for (uint256 i = 0; i < suggestionsCount; i++) {
            Suggestion memory _sugg = suggestions[i + 1];
            if (_sugg.proposer != address(0)) {
                uint256 _progress = suggestionsProgress[i + 1];
                if (_sugg.totalAmount > _progress) {
                    result[currentIndex] = SuggestionInProgress(
                        i + 1,
                        _sugg.proposer,
                        _sugg.title,
                        _sugg.description,
                        _sugg.totalAmount,
                        _progress
                    );
                    currentIndex += 1;
                }
            }
        }

        return result;
    }

    function getFinishedSuggestions()
        public
        view
        returns (FinishedSuggestion[] memory)
    {
        uint256 suggestionsCount = finishedSuggestionsCount.current();
        uint256 currentIndex = 0;

        FinishedSuggestion[] memory result = new FinishedSuggestion[](
            suggestionsCount
        );

        for (uint256 i = 0; i < suggestionsCount; i++) {
            FinishedSuggestion memory _sugg = finishedSuggestions[i + 1];
            if (_sugg.finishedFor != 0) {
                result[currentIndex] = _sugg;
            }
            currentIndex += 1;
        }

        return result;
    }

    function getWithdrawedSuggestions()
        public
        view
        returns (WithdrawedSuggestion[] memory)
    {
        uint256 suggestionsCount = withdrawedSuggestionsCount.current();
        uint256 currentIndex = 0;

        WithdrawedSuggestion[] memory result = new WithdrawedSuggestion[](
            suggestionsCount
        );

        for (uint256 i = 0; i < suggestionsCount; i++) {
            WithdrawedSuggestion memory _sugg = withdrawedSuggestions[i + 1];
            if (_sugg.widthdrawedFor != 0) {
                result[currentIndex] = _sugg;
            }
            currentIndex += 1;
        }

        return result;
    }

    function updateFibboVerification(address _verification) external onlyOwner {
        fibboVerification = IFibboVerification(_verification);
    }
}
