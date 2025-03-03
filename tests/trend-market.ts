import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures market creation works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        'trend-market',
        'create-market',
        [types.utf8("Test Market"), types.uint(1000)],
        deployer.address
      )
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    assertEquals(block.receipts[0].result, '(ok u0)');
  }
});

Clarinet.test({
  name: "Can make predictions on active markets",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        'trend-market',
        'create-market',
        [types.utf8("Test Market"), types.uint(1000)],
        deployer.address
      ),
      Tx.contractCall(
        'trend-market',
        'make-prediction',
        [types.uint(0), types.bool(true), types.uint(200)],
        wallet1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 2);
    assertEquals(block.receipts[1].result, '(ok true)');
  }
});

Clarinet.test({
  name: "Validates market resolution and reward distribution",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall(
        'trend-market',
        'create-market',
        [types.utf8("Test Market"), types.uint(1000)],
        deployer.address
      ),
      Tx.contractCall(
        'trend-market',
        'make-prediction',
        [types.uint(0), types.bool(true), types.uint(200)],
        wallet1.address
      ),
      Tx.contractCall(
        'trend-market',
        'resolve-market',
        [types.uint(0), types.bool(true)],
        deployer.address
      ),
      Tx.contractCall(
        'trend-market',
        'claim-reward',
        [types.uint(0)],
        wallet1.address
      )
    ]);
    
    assertEquals(block.receipts.length, 4);
    assertEquals(block.receipts[3].result, '(ok u400)');
  }
});
