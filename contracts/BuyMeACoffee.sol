//SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BuyMeACoffee is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public creatorId;
    Counters.Counter public donationId;

    uint256 public accountOpeningFee = 0.025 ether;
    uint256 public accountOpeningBonus = 0.01 ether;
    uint256 public transactionFees = 1; //In percent

    mapping(uint256 => Donation) donationIdToDonation;
    mapping(address => Creator) public addressToCreator; //For audience to know more about a Creator
    mapping(address => uint256) private creatorBalances; //Total Donations for a creator

    // A Creator should be able to view his received donations and messages by donationId
    mapping(address => mapping(uint256 => Donation)) private creatorToDonationId;

    struct Creator {
        uint256 creatorId;
        address creator;
        string tagLine;
    }

    struct Donation {
        uint256 donationId;
        uint256 amount;
        address sender;
        string message;
    }

    event AccountCreated(uint256 creatorId, address creator, string tagline);
    event DonationsClaimed(address creator, uint256 amount);
    event CoffeeBought(uint256 token, uint256 amount, address sender, string message);

    //Function to change the Fee Structure for Creator Account Openings
    function changeFeeStructure(uint _accountOpeningFee, uint _accountOpeningBonus, uint _transactionFees) external onlyOwner {
        accountOpeningFee = _accountOpeningFee;
        accountOpeningBonus = _accountOpeningBonus;
        transactionFees = _transactionFees;
    }

    //Function to help Creators open accounts on the platform
    function createAccount(string memory _tagline) external payable {
        require(msg.value >= accountOpeningFee, "Not enough fees");
        require(addressToCreator[msg.sender].creatorId == 0,"You already have an account");

        creatorId.increment();
        uint256 _creatorId = creatorId.current();

        addressToCreator[msg.sender] = Creator(_creatorId,msg.sender,_tagline);
        creatorBalances[msg.sender] += accountOpeningBonus;

        emit AccountCreated(_creatorId, msg.sender, _tagline);
    }

    //function to claim donations from Creator balances. 
    function claimDonations() external {
        require(creatorBalances[msg.sender] > 0, "Insufficient balance");

        (bool sent, ) = (msg.sender).call{value: creatorBalances[msg.sender]}("");
        require(sent, "Failed to send Ether"); //Transfer balance to creator

        creatorBalances[msg.sender] = 0;

        emit DonationsClaimed(msg.sender, creatorBalances[msg.sender]);
    }

    //Function to help audience to send donations(Buy Coffees) to their favorite Creators
    function buyCoffee(address _creator, string memory _message)
        external
        payable
    {
        require(msg.value >= 0, "Need more for coffee");
        require(addressToCreator[_creator].creatorId > 0, "Creator does not exist");

        donationId.increment();
        uint256 _donationId = donationId.current();

        uint256 _platformFees = msg.value * transactionFees / 100; //send 1% donation amount as fees to the platform owner
        uint256 _donationAmount = msg.value - _platformFees;
        creatorBalances[_creator] += _donationAmount;

        donationIdToDonation[_donationId] = Donation(_donationId, msg.value, msg.sender, _message);

        sendMessagesToCreator(_donationId, _creator, msg.sender, msg.value, _message);

        emit CoffeeBought(_donationId, msg.value, msg.sender, _message);
    }

    function sendMessagesToCreator(
        uint256 _donationId,
        address _creator,
        address _sender,
        uint256 _amount,
        string memory _message
    ) internal {
        creatorToDonationId[_creator][_donationId] = Donation(
            _donationId,
            _amount,
            _sender,
            _message
        );
    }
}
