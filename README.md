# Ethernaut: BetHouse

## The vulnerability

`Pool.withdrawAll()` violates checks-effects-interactions: it sends funds back
to the caller **before** burning the caller's wrapped-token balance.

```solidity
function withdrawAll() external nonReentrant {
    // 1. PDT sent back
    if (_depositedValue > 0) {
        depositedPDT[msg.sender] = 0;
        PoolToken(depositToken).transfer(msg.sender, _depositedValue);
    }

    // 2. Ether sent back  <-- hands control to caller via receive()/fallback
    if (_depositedValue > 0) {
        depositedEther[msg.sender] = 0;
        payable(msg.sender).call{value: _depositedValue}("");
    }

    // 3. Balance burned — but only AFTER the caller has already regained control
    PoolToken(wrappedToken).burn(msg.sender, balanceOf(msg.sender));
}
```

`nonReentrant` doesn't help here — it only stops `withdrawAll()` from being
called again during the reentrancy. It does nothing to stop the attacker from
calling *other* functions (`deposit`, `lockDeposits`, `BetHouse.makeBet`)
while control is handed back to them in step 2.

### The exploit path

1. Deposit 0.001 ETH + 5 PDT → mint 15 wrapped tokens (10 + 5).
2. Call `withdrawAll()`.
3. Step 2 of `withdrawAll()` sends the ether back, triggering our contract's
   `receive()` before the burn in step 3 happens.
4. Inside `receive()`, while our wrapped balance is still 15 (unburned):
   - Re-deposit the 5 PDT we just got back → mint 5 more → balance = 20 =
     `BET_PRICE`.
   - Call `lockDeposits()`.
   - Call `BetHouse.makeBet(player)`, which checks `balanceOf(msg.sender) >=
     20` and `depositsLocked(msg.sender)` — both true at this exact instant.
5. `receive()` returns, `withdrawAll()` resumes and burns our balance — too
   late, `player` is already registered as a bettor.

## Lessons learnt

> **Note:** everything below is a personal, informal set of notes written
> from my own experience solving this level — not a formal audit checklist
> or a claim about best practice in general. Take it as "what I wish I'd
> known going in," not gospel.

**How I actually got to the vulnerability (and how others likely would too):**
- I ran invariant/fuzz tests first and they all passed — which felt
  reassuring but was misleading. Standard invariant tests only exercise
  call sequences your test harness's target contracts can produce. Mine
  only called `Pool`'s functions from plain actors, so no sequence ever
  *reentered* mid-call — nothing in the harness had a fallback that called
  back into the system. **A reentrancy bug is invisible to invariant
  testing unless an adversarial contract (one whose `receive()`/fallback
  calls back into the target) is explicitly included as a fuzzed
  participant.** Green invariant tests here meant "the attacker wasn't in
  the test universe," not "the code is safe."
- What actually got me there was a hint pointing at reentrancy, followed by
  manually reading `withdrawAll()` end to end. In hindsight, the reliable
  manual method is a simple checklist: find every external call in a
  function, then list everything that runs *after* it. If any of that
  "after" code writes state that a security check elsewhere depends on,
  that's a checks-effects-interactions violation — regardless of whether a
  reentrancy guard is present. `withdrawAll()` fails this immediately: it
  sends ether back, and only *after* that burns the balance that
  `BetHouse.makeBet()` checks.
- `nonReentrant` created a false sense of safety for me at first glance —
  worth specifically asking, whenever you see that modifier, "guarded
  against reentering *this* function, sure — but what else could an
  attacker do with control during the external call?"
- I didn't run it this time, but static analysis (e.g. Slither) has a
  reentrancy detector that flags exactly this external-call-before-state-write
  pattern mechanically, without needing a hint or a manual read-through.
  Probably worth running early next time, alongside manual CEI review —
  the tool catches the mechanical pattern, the manual read explains *why*
  it's exploitable in this specific cross-contract setup.

**Contract-level (Solidity/security):**
- **Checks-effects-interactions matters even with a reentrancy guard.**
  `nonReentrant` only blocks re-entering the *same* guarded function. It does
  not stop the attacker from calling *unguarded* functions on other contracts
  during the callback window. State (like burning a balance) that a
  security-critical check depends on must be updated *before* any external
  call, not after.
- **A single boolean state flag (e.g. `alreadyDeposited`) that isn't scoped
  per-address is a footgun**, even outside the main exploit path — it can
  quietly break re-runs and desync your mental model of "what state should
  the contract be in."

**Foundry / tooling (the part that actually cost the most debugging time):**
- **`vm.deal` is a local-simulation cheatcode only.** It has zero effect once
  you're broadcasting to a real chain — you must send real ETH from a
  funded account instead.
- **Anything deployed or state-changing must happen *inside*
  `vm.startBroadcast()`/`stopBroadcast()`, inside `run()` — never in
  `setUp()`.** `setUp()` runs in local simulation only; deploying a contract
  there gives you a real-looking address that has no code on the actual
  chain. Calls to such an address silently no-op instead of reverting, which
  made this bug much harder to spot than a normal revert would have been.
- **A near-baseline gas cost (~21,000 gas) on a transaction that should do a
  lot of work is a strong signal you're calling an address with no
  bytecode.** Worth checking early rather than assuming "success" means
  "did what I expected."
- **An unconditional `receive()` fires on *any* incoming ether**, including
  plain funding transfers from your deploy script — not just the reentrant
  callback you're trying to exploit. Guard it with `if (msg.sender !=
  address(pool)) return;` (or equivalent) so it only runs the exploit logic
  when the ether genuinely comes from the contract being attacked.
- **Declaring script variables as contract-level state (outside `run()`) is
  the idiomatic Foundry pattern** — it's not a mistake by itself. What
  matters is *when* they're assigned: `setUp()` for read-only wiring to
  existing on-chain contracts, `run()` + broadcast for anything that deploys
  or sends a transaction.
- Prefer custom errors (`error Foo(); ... if (!ok) revert Foo();`) over
  `require(cond, "string")` — cheaper bytecode and clearer traces.

## Running it

```bash
forge script script/BetHouseSolverScript.s.sol \
  --rpc-url $RPC_URL \
  --account TestAccount \
  --broadcast --verify --skip-simulation -vvvv
```

Verify the result directly on-chain rather than trusting only the CLI output:

```bash
cast call <BET_HOUSE_ADDRESS> "isBettor(address)(bool)" <YOUR_ADDRESS> --rpc-url $RPC_URL
```

Or the same with environment viriables used in the script:

```bash
cast call $LEVEL "isBettor(address)(bool)" $MY_ADDRESS --rpc-url $RPC_URL
```
