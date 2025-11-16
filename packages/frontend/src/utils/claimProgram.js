import { Connection, PublicKey, Transaction, SystemProgram } from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, getAssociatedTokenAddress, createAssociatedTokenAccountInstruction, getAccount } from '@solana/spl-token';
import idl from '../idl/bux_claim.json';
import { PROJECT_CONFIG } from '../config.js';

// Mainnet BUX token mint and program addresses
const TOKEN_MINT_ADDRESS = PROJECT_CONFIG.rewards?.tokenMint || 'FMiRxSbLqRTWiBszt1DZmXd7SrscWCccY7fcXNtwWxHK';
const PROGRAM_ID = new PublicKey(PROJECT_CONFIG.rewards?.claimProgramId || 'AzjaVGh81f1jZtZvouZ4pccaRoPvCcB87Vu2fRDWV5et');
const TREASURY_TOKEN_ACCOUNT = new PublicKey(PROJECT_CONFIG.rewards?.treasuryTokenAccount || '8CL3xrVkeeUZXA1uC3WRheSyUPEW7LwhaJ9uqPeHLo6k');
const REWARD_MINT = new PublicKey(TOKEN_MINT_ADDRESS);

export class ClaimProgram {
  constructor(connection, walletAdapter) {
    this.connection = connection;
    this.walletAdapter = walletAdapter;
    
    console.log('Creating ClaimProgram with wallet adapter:', walletAdapter);
    console.log('Wallet adapter adapter:', walletAdapter.adapter);
    console.log('Wallet adapter publicKey:', walletAdapter.publicKey);
    
    // The wallet adapter structure has the actual wallet in the adapter property
    const actualWallet = walletAdapter.adapter;
    
    console.log('Created wallet object with publicKey:', actualWallet.publicKey);
  }

  async claim(amount) {
    try {
      console.log('Claim amount:', amount);
      console.log('Amount type:', typeof amount);
      
      const userPublicKey = this.walletAdapter.adapter.publicKey;
      console.log('User public key:', userPublicKey.toString());
      
      // Get user's token account
      const userTokenAccount = await getAssociatedTokenAddress(
        REWARD_MINT,
        userPublicKey
      );
      console.log('User token account:', userTokenAccount.toString());

      // Check if user token account exists
      let userTokenAccountExists = false;
      try {
        await getAccount(this.connection, userTokenAccount);
        userTokenAccountExists = true;
        console.log('User token account exists');
      } catch (error) {
        console.log('User token account does not exist, will create it');
        userTokenAccountExists = false;
      }

      // Find treasury authority PDA
      const [treasuryAuthority] = PublicKey.findProgramAddressSync(
        [Buffer.from('treasury')],
        PROGRAM_ID
      );
      console.log('Treasury authority PDA:', treasuryAuthority.toString());

      // Create the claim instruction data
      // The instruction data format for Anchor is: [discriminator (8 bytes)] + [amount (8 bytes)]
      const instructionData = Buffer.alloc(16);
      
      // Correct Anchor discriminator for "claim" instruction (first 8 bytes of sha256("global:claim"))
      const claimDiscriminator = Buffer.from([
        0x3e, 0xc6, 0xd6, 0xc1, 0xd5, 0x9f, 0x6c, 0xd2
      ]);
      instructionData.set(claimDiscriminator, 0);
      
      // Amount as little-endian u64 (next 8 bytes)
      const amountBuffer = Buffer.alloc(8);
      amountBuffer.writeBigUInt64LE(BigInt(amount), 0);
      instructionData.set(amountBuffer, 8);
      
      console.log('Instruction data:', instructionData.toString('hex'));

      // Create transaction
      const transaction = new Transaction();

      // Add create token account instruction if needed
      if (!userTokenAccountExists) {
        console.log('Adding create token account instruction');
        const createAccountInstruction = createAssociatedTokenAccountInstruction(
          userPublicKey, // payer
          userTokenAccount, // associated token account
          userPublicKey, // owner
          REWARD_MINT // mint
        );
        transaction.add(createAccountInstruction);
      }

      // Create the claim instruction
      const claimInstruction = {
        programId: PROGRAM_ID,
        keys: [
          { pubkey: TREASURY_TOKEN_ACCOUNT, isSigner: false, isWritable: true },
          { pubkey: userTokenAccount, isSigner: false, isWritable: true },
          { pubkey: treasuryAuthority, isSigner: false, isWritable: false },
          { pubkey: TOKEN_PROGRAM_ID, isSigner: false, isWritable: false },
        ],
        data: instructionData
      };

      transaction.add(claimInstruction);
      
      console.log('Transaction created with claim instruction');
      
      // Get recent blockhash
      const { blockhash } = await this.connection.getLatestBlockhash();
      transaction.recentBlockhash = blockhash;
      transaction.feePayer = userPublicKey;
      
      console.log('Transaction prepared with blockhash:', blockhash);
      
      // Sign and send transaction using the wallet adapter
      const signature = await this.walletAdapter.adapter.sendTransaction(transaction, this.connection);
      console.log('Transaction sent with signature:', signature);
      
      await this.connection.confirmTransaction(signature, 'confirmed');
      console.log('Transaction confirmed!');

      return {
        success: true,
        signature,
        message: 'Claim successful!'
      };
    } catch (error) {
      console.error('Claim error:', error);
      return {
        success: false,
        error: error.message,
        message: 'Claim failed'
      };
    }
  }

  async getUserBalance() {
    try {
      const userTokenAccount = await getAssociatedTokenAddress(
        REWARD_MINT,
        this.walletAdapter.adapter.publicKey
      );

      const balance = await this.connection.getTokenAccountBalance(userTokenAccount);
      return balance.value.uiAmount || 0;
    } catch (error) {
      console.error('Error getting balance:', error);
      return 0;
    }
  }
}

export default ClaimProgram; 