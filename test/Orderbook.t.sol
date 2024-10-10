// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../src/OrderBook.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OrderBookTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    OrderBook orderBook;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        orderBook = new OrderBook(tokenA, tokenB);

        tokenA.mint(alice, 1000 * 10 ** tokenA.decimals());
        tokenB.mint(bob, 1000 * 10 ** tokenB.decimals());

        vm.startPrank(alice);
        tokenA.approve(address(orderBook), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenB.approve(address(orderBook), type(uint256).max);
        vm.stopPrank();
    }

    function testPlaceOrder() public {
        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        (address maker, uint256 amount,,) = orderBook.orders(orderId);
        assertEq(maker, alice);
        assertEq(amount, 100);
        vm.stopPrank();
    }

    function testPlaceOrderFailed() public {
        // Test: Montant invalide (0)
        vm.startPrank(alice);
        vm.expectRevert("Amount must be greater than 0");
        orderBook.placeOrder(0, 1, false);
        vm.stopPrank();

        // Test: Prix invalide (0)
        vm.startPrank(alice);
        vm.expectRevert("Price must be greater than 0");
        orderBook.placeOrder(100, 0, false);
        vm.stopPrank();
    }


    function testCancelOrder() public {
        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        orderBook.cancelOrder(orderId);
        (, uint256 amount,,) = orderBook.orders(orderId);
        assertEq(amount, 0);
        vm.stopPrank();
    }

    function testCancelOrderFailed() public {
        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        vm.stopPrank();

        // Test: Annulation par une personne non autorisée (Bob essaie d'annuler l'ordre d'Alice)
        vm.startPrank(bob);
        vm.expectRevert("Not the order creator");
        orderBook.cancelOrder(orderId);
        vm.stopPrank();

        // Test: Tentative d'annulation d'un ordre inexistant
        vm.startPrank(alice);
        uint256 nonExistentOrderId = 9999;
        vm.expectRevert();
        orderBook.cancelOrder(nonExistentOrderId);
        vm.stopPrank();
    }

    function testFillOrder() public {
        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        vm.stopPrank();

        vm.startPrank(bob);
        orderBook.fillOrder(orderId, 50);
        vm.stopPrank();

        (, uint256 amount,,) = orderBook.orders(orderId);
        assertEq(amount, 50);
    }

    function testFillOrderFailed() public {
        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        vm.stopPrank();

        // Test: Remplir un ordre avec un montant supérieur à ce qui est disponible
        vm.startPrank(bob);
        vm.expectRevert("Not enough tokens available");
        orderBook.fillOrder(orderId, 200);
        vm.stopPrank();

        // Test: Remplir un ordre sans avoir approuvé suffisamment de tokens
        vm.startPrank(bob);
        tokenB.approve(address(orderBook), 10); 
        vm.expectRevert();  
        orderBook.fillOrder(orderId, 50);
        vm.stopPrank();

        // Test: Remplir un ordre inexistant
        vm.startPrank(bob);
        uint256 nonExistentOrderId = 9999;
        vm.expectRevert(); 
        orderBook.fillOrder(nonExistentOrderId, 50);
        vm.stopPrank();
    }

    function testRecordTransaction() public {
        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        vm.stopPrank();

        vm.startPrank(bob);
        orderBook.fillOrder(orderId, 50);
        vm.stopPrank();

        OrderBook.Transaction memory txn = orderBook.getTransaction(0);

        assertEq(txn.maker, alice);
        assertEq(txn.taker, bob);
        assertEq(txn.amount, 50);
        assertEq(txn.price, 1);
        assertEq(txn.isBuyOrder, false);
        assertGt(txn.timestamp, 0);
    }

    function testRecordTransactionFailed() public {
        // Test: Remplir un ordre inexistant
        vm.startPrank(bob);
        uint256 nonExistentOrderId = 9999; 
        vm.expectRevert(); 
        orderBook.fillOrder(nonExistentOrderId, 50);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 orderId = orderBook.placeOrder(100, 1, false);
        vm.stopPrank();

        // Test: Tentative de remplir l'ordre mais sans avoir approuvé assez de tokens
        vm.startPrank(bob);
        tokenB.approve(address(orderBook), 10);
        vm.expectRevert();  
        orderBook.fillOrder(orderId, 50);
        vm.stopPrank();

        assertEq(orderBook.transactionCount(), 0);
    }

}
