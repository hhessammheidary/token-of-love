// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Chainlink, ChainlinkClient} from "@chainlink/contracts@1.1.1/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@1.1.1/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts@1.1.1/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract TOL is IERC20, ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
    
    mapping(address => address) public friends;
    mapping(address => uint) public lastThoughtTime;
    mapping(address => bool) public hasThoughtInCurrentPeriod;
    mapping(address => uint256) public togetherMintedBalance;
    mapping(address => uint256) public blockedBalance;
    mapping(address => uint256) public balances;
    mapping(address => bool) public goOut;
    mapping(address => mapping(address => uint256)) public _allowance;
    uint total;

    event Friendship(address indexed user1, address indexed user2);
    event TOLMinted(address indexed user, string reason, uint256 amount);
    event Separated(address indexed user1, address indexed user2);
    uint256 public isRainy;
    uint256 public fee;
    string[] public temp;

    constructor() ConfirmedOwner(msg.sender) {
        _setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0.1 LINK
    }

    function requestWeatherData(address _oracle, string memory _jobId) public onlyOwner {
        Chainlink.Request memory req = _buildChainlinkRequest(
            stringToBytes32(_jobId), address(this), this.fulfill.selector);
        req._add(
            "get",
            "https://api.open-meteo.com/v1/forecast?latitude=35.6944&longitude=51.4215&current=rain"
        );
        
        temp.push("current");
        temp.push("rain");
        req._addStringArray("path", temp);
        _sendChainlinkRequestTo(_oracle, req, fee);
    }

    function letsGoOut() public single {
        //require(oracle.isRainy() == 1, "It is not rainy in Tehran");
        require(isRainy == 0, "It is not rainy in Tehran");
        
        address friend = friends[msg.sender];
        if(goOut[msg.sender] == false) {
            goOut[msg.sender] = true;
        }
        if (goOut[friend] == true) {
            mint(msg.sender, 500);
            mint(friend, 500);
            togetherMintedBalance[msg.sender] += 500;
            togetherMintedBalance[friend] += 500;
            emit TOLMinted(msg.sender, "Rainy day", 500);
        }
    }

    function fulfill(bytes32 _requestId, uint256 _isRainy) public recordChainlinkFulfillment(_requestId) {
        emit RequestWeatherData(_requestId, _isRainy);
        isRainy = _isRainy;
    }

    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }

    

    function weAreFriends(address _friend) public {
        require(friends[msg.sender] == address(0), "Are you non-monogamous?");
        //require(_friend != msg.sender, "You can't be friends with yourself");
        require(friends[_friend] == address(0) || friends[_friend] == msg.sender,
            "User is friends with someone else");

        friends[msg.sender] = _friend;
        friends[_friend] = msg.sender;
        emit Friendship(msg.sender, _friend);
    }

    function thoughtOfThem() public single {
        uint time = block.timestamp;
        uint hour = time / 60 / 60 % 24;
        uint minute = time / 60 % 60;
        uint second = time % 60;
        require(hour == 13 && (minute <= 50 && minute >= 10), "It is not 11:11 now");
        address friend = friends[msg.sender];
        if (lastThoughtTime[friend] / 1 days == time / 1 days && hasThoughtInCurrentPeriod[friend]) {
            mint(msg.sender, 100);
            mint(friend, 100);
            togetherMintedBalance[msg.sender] += 100;
            togetherMintedBalance[friend] += 100;

            hasThoughtInCurrentPeriod[msg.sender] = false;
            hasThoughtInCurrentPeriod[friend] = false;
        } else {
            lastThoughtTime[msg.sender] = time;
            hasThoughtInCurrentPeriod[msg.sender] = true;
        }
    }



    

    function weCut() public single {
        address exFriend = friends[msg.sender];
        friends[msg.sender] = address(0);
        friends[exFriend] = address(0);
        blockedBalance[msg.sender] += togetherMintedBalance[msg.sender];
        blockedBalance[exFriend] += togetherMintedBalance[exFriend];
        togetherMintedBalance[msg.sender] = 0;
        togetherMintedBalance[exFriend] = 0;
        emit Separated(msg.sender, exFriend);
    }

    function mint(address user, uint256 amount) internal {
        balances[user] += amount;
        total += amount;
        emit TOLMinted(user, "Happy 11:11, get that TOL", amount);
    }

    function totalSupply() external view override returns (uint256) {
        return total;
    }

    function transfer(address to, uint256 value) external override cantTransferAfterSeparation(msg.sender, value) returns (bool) {
        require(balances[msg.sender] >= value, "You don't have that money");
        balances[msg.sender] -= value;
        balances[to] += value;
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowance[owner][spender];
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override cantTransferAfterSeparation(from, value) returns (bool) {
        require(_allowance[from][msg.sender] >= value, "You can't use this amount of money");
        require(balances[from] >= value, "Owner doesn't have that money");
        _allowance[from][msg.sender] -= value;
        balances[from] -= value;
        balances[to] += value;
        return true;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    modifier single {
        require(friends[msg.sender] != address(0), "You are single, my friend");
        _;
    }

    modifier cantTransferAfterSeparation(address from, uint256 value) {
        require(balances[from] - value >= blockedBalance[from],
            "You can't transfer tokens minted while together after separation");
        _;
    }



    event RequestWeatherData(bytes32 indexed requestId, uint256 isRainy);

}
