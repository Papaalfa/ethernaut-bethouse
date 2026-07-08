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
        // Deploy PDT
        pdt = new PoolToken("Pool Deposit Token", "PDT");
        
        // Deploy Wrapped Token
        wrappedToken = new PoolToken("Wrapped Token", "WTOKEN");
        
        // Deploy Pool
        pool = new Pool(address(wrappedToken), address(pdt));
        
        // Set Pool as owner of wrapped token
        wrappedToken.transferOwnership(address(pool));
        
        // Deploy BetHouse
        betHouse = new BetHouse(address(pool));

        // Give player initial PDT
        pdt.mint(player, 5);

        // Create Handler
        handler = new BetHouseHandler(betHouse, pool, wrappedToken, pdt, player);

        // Target the handler for invariant testing
        targetContract(address(handler));

        // Give player some ETH
        vm.deal(player, 10 ether);
    }

    // ================== INVARIANT TESTS ==================

    function invariant_WrappedSupplyConsistent() public {
        handler.invariant_WrappedSupplyConsistent();
    }

    function invariant_BettorHasEnoughTokens() public {
        handler.invariant_BettorHasEnoughTokens();
    }

    function invariant_BalanceLETotalSupply() public {
        handler.invariant_BalanceLETotalSupply();
    }

    function invariant_PoolOwnsWrappedToken() public {
        handler.invariant_PoolOwnsWrappedToken();
    }

    function invariant_NoNegativeValues() public {
        handler.invariant_NoNegativeValues();
    }

    function invariant_GettersDontRevert() public {
        handler.invariant_GettersDontRevert();
    }

    // Run with more runs for better coverage
    function testInvariant() public {
        // You can run this to see stats
        handler.logStats();
    }
}