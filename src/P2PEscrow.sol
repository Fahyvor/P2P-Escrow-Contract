// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract P2PEscrow {
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
    address public admin;

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
    function createTrade(address _seller, address token, uint256 amount) external {
        require(_seller != address(0), "Invalid seller address");
        require(amount > 0, "Amount must be greater than zero");
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        trades[tradeCount] = Trade({
            seller: _seller,
            buyer: address(0),
            token: token,
            amount: amount,
            status: TradeStatus.Pending
        });

        emit TradeCreated(tradeCount, address(this), _seller, amount);

        tradeCount++;
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

        IERC20(trade.token).transfer(trade.seller, trade.amount);

        emit TradeReleased(tradeId);
        trade.status = TradeStatus.Released;
    }

    // Cancel Trade Function
    function cancelTrade(uint256 tradeId) external onlySeller(tradeId) {
        Trade storage trade = trades[tradeId];
        require(trade.status == TradeStatus.Pending, "Cannot cancel trade");

        trade.status = TradeStatus.Cancelled;
        IERC20(trade.token).transfer(trade.seller, trade.amount);
        emit TradeCancelled(tradeId);
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
        IERC20(trade.token).transfer(to, trade.amount);
        emit TradeResolved(tradeId, to);
    }

    // Get total trades function
    function getTotalTrades() external view returns (uint256) {
        return tradeCount;
    }
}