// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {BetHouse} from "../src/BetHouse.sol";
import {Pool} from "../src/Pool.sol";
import {PoolToken} from "../src/PoolToken.sol";

contract BetHouseTest is Test {
    BetHouse public betHouse;
    Pool public pool;
    PoolToken public wrappedToken;
    PoolToken public pdt;

    address public player = makeAddr("player");

    function setUp() public {
        // Deploy tokens
        pdt = new PoolToken("Pool Deposit Token", "PDT");
        wrappedToken = new PoolToken("Wrapped Token", "WTOKEN");

        // Deploy Pool
        pool = new Pool(address(wrappedToken), address(pdt));

        // Transfer ownership of wrapped token to Pool
        wrappedToken.transferOwnership(address(pool));

        // Deploy BetHouse
        betHouse = new BetHouse(address(pool));

        // Give player 5 PDT
        pdt.mint(player, 5); // assuming 18 decimals, adjust if needed
    }

    function testDepositNormal() public {
        vm.startPrank(player);

        // Give the player some ETH
        vm.deal(player, 1 ether);

        pdt.approve(address(pool), type(uint256).max);

        // Deposit PDT + ETH
        pool.deposit{value: 0.001 ether}(5);

        console.log("Wrapped balance:", pool.balanceOf(player));
        vm.stopPrank();
    }
}
