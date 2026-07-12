// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BetHouse} from "../src/BetHouse.sol";
import {Pool} from "../src/Pool.sol";
import {PoolToken} from "../src/PoolToken.sol";
import {BetHouseHandler} from "./BetHouseHandler.t.sol";

contract BetHouseInvariantTest is StdInvariant, Test {
    BetHouse public betHouse;
    Pool public pool;
    PoolToken public wrappedToken;
    PoolToken public pdt;
    BetHouseHandler public handler;

    address public player = makeAddr("player");

    function setUp() public {
        pdt = new PoolToken("Pool Deposit Token", "PDT");
        wrappedToken = new PoolToken("Wrapped Token", "WTOKEN");
        
        pool = new Pool(address(wrappedToken), address(pdt));
        wrappedToken.transferOwnership(address(pool));
        
        betHouse = new BetHouse(address(pool));

        // Правильное количество PDT
        pdt.mint(player, 5);

        handler = new BetHouseHandler(betHouse, pool, wrappedToken, pdt, player);

        targetContract(address(handler));

        vm.deal(player, 10 ether);
    }

    function invariant_WrappedSupplyConsistent() public { handler.invariant_WrappedSupplyConsistent(); }
    function invariant_BettorHasEnoughTokens() public { handler.invariant_BettorHasEnoughTokens(); }
    function invariant_BalanceLETotalSupply() public { handler.invariant_BalanceLETotalSupply(); }
    function invariant_PoolOwnsWrappedToken() public { handler.invariant_PoolOwnsWrappedToken(); }
    function invariant_NoNegativeValues() public { handler.invariant_NoNegativeValues(); }
    function invariant_GettersDontRevert() public { handler.invariant_GettersDontRevert(); }

    function testInvariant() public {
        handler.logStats();
    }
}