// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract P2PEscrow is ReentrancyGuard {
    enum TradeStatus { Pending, Accepted, Released, Cancelled, Disputed }

    struct Trade {
        address buyer;
        address seller;
        address token;
        uint256 amount;
        TradeStatus status;
    }

    uint256 public tradeCount;
    mapping(uint256 => Trade) public trades;
    address public immutable admin;

    constructor() {
        admin = msg.sender;
    }

    event TradeCreated(uint256 tradeId, address buyer, address seller, uint256 amount);
    event TradeAccepted(uint256 tradeId, address buyer);
    event TradeReleased(uint256 tradeId);
    event TradeCancelled(uint256 tradeId);
    event TradeDisputed(uint256 tradeId);
    event TradeResolved(uint256 tradeId, address to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyBuyer(uint256 tradeId) {
        require(msg.sender == trades[tradeId].buyer, "Only buyer can call this function");
        _;
    }

    modifier onlySeller(uint256 tradeId) {
        require(msg.sender == trades[tradeId].seller, "Only seller can call ths function");
        _;
    }

    //Create Trade Function
    function createTrade(address token, uint256 amount) external returns (uint256) {
        require(msg.sender != address(0), "Invalid seller address");
        require(amount > 0, "Amount must be greater than zero");

         uint256 currentTradeId = tradeCount;

        trades[tradeCount] = Trade({
            seller: msg.sender,
            buyer: address(0),
            token: token,
            amount: amount,
            status: TradeStatus.Pending
        });

        return tradeCount++;

        emit TradeCreated(tradeCount, address(this), msg.sender, amount);

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        return currentTradeId;
    }

    // Accept Trade Function
    function acceptTrade(uint256 tradeId) external onlyBuyer(tradeId) {
        Trade storage trade = trades[tradeId];
        require(trade.status == TradeStatus.Pending, "Trade is not pending");

        trade.buyer = msg.sender;
        trade.status = TradeStatus.Accepted;
        emit TradeAccepted(tradeId, msg.sender);
    }

    // Release Trade Function
    function releaseFunds(uint256 tradeId) external onlySeller(tradeId) {
        Trade storage trade = trades[tradeId];
        require(trade.status == TradeStatus.Accepted, "Trade is not accepted");
        trade.status = TradeStatus.Released;
        emit TradeReleased(tradeId);
        require(IERC20(trade.token).transfer(trade.seller, trade.amount), "Token transfer failed");
    }

    // Cancel Trade Function
    function cancelTrade(uint256 tradeId) external onlySeller(tradeId) {
        Trade storage trade = trades[tradeId];
        require(trade.status == TradeStatus.Pending, "Cannot cancel trade");

        trade.status = TradeStatus.Cancelled;
        emit TradeCancelled(tradeId);
        require(IERC20(trade.token).transfer(trade.seller, trade.amount), "Token transfer failed");
    }

    // Dispute Trade Function
    function disputeTrade(uint256 tradeId) external {
        Trade storage trade = trades[tradeId];
        require(msg.sender == trade.buyer || msg.sender == trade.seller, "Only buyer or seller can dispute");
        require(trade.status == TradeStatus.Accepted, "Trade is not accepted");

        trade.status = TradeStatus.Disputed;
        emit TradeDisputed(tradeId);
    }

    // Resolve Trade Function
    function resolveDispute(uint256 tradeId, address to) external onlyAdmin {
        Trade storage trade = trades[tradeId];
        require(trade.status == TradeStatus.Disputed, "This trade is not disputed");

        trade.status = TradeStatus.Released;
        emit TradeResolved(tradeId, to);
        require(IERC20(trade.token).transfer(to, trade.amount), "Token transfer failed");
    }

    // Get total trades function
    function getTotalTrades() external view returns (uint256) {
        return tradeCount;
    }
}