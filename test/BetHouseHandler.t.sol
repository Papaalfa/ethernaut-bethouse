// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {BetHouse} from "../src/BetHouse.sol";
import {Pool} from "../src/Pool.sol";
import {PoolToken} from "../src/PoolToken.sol";

contract BetHouseHandler is Test {
    BetHouse public betHouse;
    Pool public pool;
    PoolToken public wrappedToken;
    PoolToken public pdt;

    address public player;

    uint256 public timesDepositCalled;
    uint256 public timesLockCalled;
    uint256 public timesMakeBetCalled;
    uint256 public timesWithdrawCalled;

    constructor(BetHouse _betHouse, Pool _pool, PoolToken _wrapped, PoolToken _pdt, address _player) {
        betHouse = _betHouse;
        pool = _pool;
        wrappedToken = _wrapped;
        pdt = _pdt;
        player = _player;
    }

    // ================== PUBLIC FUNCTIONS FOR FUZZING ==================

    function deposit(uint256 pdtAmount) public {
        pdtAmount = bound(pdtAmount, 0, 500 ether);

        vm.startPrank(player);
        pdt.approve(address(pool), pdtAmount);

        try pool.deposit{value: 0.001 ether}(pdtAmount) {
            timesDepositCalled++;
        } catch {}
        vm.stopPrank();
    }

    function lockDeposits() public {
        vm.startPrank(player);
        try pool.lockDeposits() {
            timesLockCalled++;
        } catch {}
        vm.stopPrank();
    }

    function makeBet() public {
        vm.startPrank(player);
        try betHouse.makeBet(player) {
            timesMakeBetCalled++;
        } catch {}
        vm.stopPrank();
    }

    function withdrawAll() public {
        vm.startPrank(player);
        try pool.withdrawAll() {
            timesWithdrawCalled++;
        } catch {}
        vm.stopPrank();
    }

    // ================== INVARIANTS ==================

    /// @notice Wrapped supply cannot exceed deposited assets
    function invariant_WrappedSupplyConsistent() public view {
        uint256 totalSupply = wrappedToken.totalSupply();
        uint256 pdtInPool = pdt.balanceOf(address(pool));
        uint256 ethInPool = address(pool).balance;

        uint256 maxExpected = pdtInPool + (ethInPool >= 0.001 ether ? 10 ether : 0);
        assertLe(totalSupply, maxExpected, "Wrapped supply > deposited assets");
    }

    /// @notice Bettor must have at least 20 wrapped tokens
    function invariant_BettorHasEnoughTokens() public view {
        if (betHouse.isBettor(player)) {
            uint256 balance = pool.balanceOf(player);
            assertGe(balance, 20 ether, "Bettor must have >= 20 wrapped tokens");
        }
    }

    /// @notice User balance cannot exceed total supply
    function invariant_BalanceLETotalSupply() public view {
        uint256 userBalance = pool.balanceOf(player);
        uint256 totalSupply = wrappedToken.totalSupply();
        assertLe(userBalance, totalSupply);
    }

    /// @notice Pool is owner of wrapped token
    function invariant_PoolOwnsWrappedToken() public view {
        assertEq(wrappedToken.owner(), address(pool));
    }

    /// @notice No negative balances or supply
    function invariant_NoNegativeValues() public view {
        assertGe(wrappedToken.totalSupply(), 0);
        assertGe(pool.balanceOf(player), 0);
    }

    /// @notice Getters should not revert
    function invariant_GettersDontRevert() public view {
        pool.depositsLocked(player);
        pool.balanceOf(player);
        betHouse.isBettor(player);
        wrappedToken.balanceOf(player);
    }

    // Helper to see stats
    function logStats() public view {
        console.log("=== Handler Stats ===");
        console.log("Deposits called:", timesDepositCalled);
        console.log("Locks called:", timesLockCalled);
        console.log("MakeBet called:", timesMakeBetCalled);
        console.log("Withdraws called:", timesWithdrawCalled);
        console.log("Player wrapped balance:", pool.balanceOf(player));
        console.log("Is bettor:", betHouse.isBettor(player));
    }
}