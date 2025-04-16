// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/P2PEscrow.sol";

contract TokenMock is IERC20 {
    string public name = "Elrey Mock";
    string public symbol = "ELR";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        _mint(msg.sender, 1_000_000 ether);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(allowance[from][msg.sender] >= amount, "You have exceeded your allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
    }
}

contract P2PEscrowTest is Test {
    P2PEscrow public escrow;
    TokenMock public token;

    address seller = address(0x1);
    address buyer = address(0x2);

    function setUp() public {
        escrow = new P2PEscrow();
        token = new TokenMock();

        token.transfer(seller, 1000 ether);
        // vm.prank(seller) sets the msg.sender to the seller address so that
        // the following operations are executed as if the seller was calling
        // them. This is useful to test the contract in different scenarios.
        vm.prank(seller);
        token.approve(address(escrow), 1000 ether);
    }

    function testCreateTrade() public {
        vm.startPrank(seller);
        uint tradeId = escrow.createTrade(address(token), 100 ether);
        (, , , uint amount, ) = escrow.trades(tradeId);
        assertEq(amount, 100 ether);
        vm.stopPrank();
    }
}