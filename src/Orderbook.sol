// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract OrderBook {
    struct Order {
        address maker;
        uint256 amount;
        uint256 price;
        bool isBuyOrder;
    }

    struct Transaction {
        address maker;
        address taker;
        uint256 amount;
        uint256 price;
        bool isBuyOrder;
        uint256 timestamp;
    }

    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public orderCount;
    uint256 public transactionCount;
    
    mapping(uint256 => Order) public orders;
    mapping(uint256 => Transaction) public transactions;

    event OrderPlaced(uint256 indexed orderId, address indexed maker, uint256 amount, uint256 price, bool isBuyOrder);
    event OrderCancelled(uint256 indexed orderId);
    event OrderFilled(uint256 indexed orderId, address indexed taker, uint256 amount);
    event TransactionRecorded(uint256 indexed transactionId, address indexed maker, address indexed taker, uint256 amount, uint256 price, bool isBuyOrder);

    constructor(IERC20 _tokenA, IERC20 _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function placeOrder(uint256 amount, uint256 price, bool isBuyOrder) external returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(price > 0, "Price must be greater than 0");

        if (isBuyOrder) {
            require(tokenB.transferFrom(msg.sender, address(this), amount * price), "Token transfer failed");
        } else {
            require(tokenA.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        }

        orders[orderCount] = Order({
            maker: msg.sender,
            amount: amount,
            price: price,
            isBuyOrder: isBuyOrder
        });

        emit OrderPlaced(orderCount, msg.sender, amount, price, isBuyOrder);

        return orderCount++;
    }

    function cancelOrder(uint256 orderId) external {
        Order memory order = orders[orderId];
        require(order.maker == msg.sender, "Not the order creator");

        if (order.isBuyOrder) {
            require(tokenB.transfer(order.maker, order.amount * order.price), "Token refund failed");
        } else {
            require(tokenA.transfer(order.maker, order.amount), "Token refund failed");
        }

        delete orders[orderId];
        emit OrderCancelled(orderId);
    }

    function fillOrder(uint256 orderId, uint256 amount) external {
        Order storage order = orders[orderId];
        require(order.amount >= amount, "Not enough tokens available");

        if (order.isBuyOrder) {
            require(tokenA.transferFrom(msg.sender, order.maker, amount), "Token A transfer failed");
            require(tokenB.transfer(msg.sender, amount * order.price), "Token B transfer failed");
        } else {
            require(tokenB.transferFrom(msg.sender, order.maker, amount * order.price), "Token B transfer failed");
            require(tokenA.transfer(msg.sender, amount), "Token A transfer failed");
        }

        transactions[transactionCount] = Transaction({
            maker: order.maker,
            taker: msg.sender, 
            amount: amount,
            price: order.price,
            isBuyOrder: order.isBuyOrder,
            timestamp: block.timestamp
        });

        transactionCount++;

        order.amount -= amount;
        if (order.amount == 0) {
            delete orders[orderId];
        }

        emit OrderFilled(orderId, msg.sender, amount);
    }

    function getTransaction(uint256 transactionId) public view returns (Transaction memory) {
        return transactions[transactionId];
    }
}
