import React, { useState } from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { Transaction } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { API_BASE_URL, TOKEN_SYMBOL } from '../config.js';

const BuxClaimButton = ({ 
  amount, 
  onSuccess, 
  onError,
  disabled,
  className,
  children 
}) => {
  const { publicKey, signTransaction, connected } = useWallet();
  const [isLoading, setIsLoading] = useState(false);

  const handleClaim = async () => {
    if (!publicKey || !signTransaction) {
      onError?.(new Error('Wallet not connected'));
      return;
    }

    setIsLoading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/api/user/claim`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify({
          walletAddress: publicKey.toString(),
          amount
        })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to process claim');
      }

      const responseData = await response.json();
      const { transaction: serializedTx } = responseData;

      if (!serializedTx) {
        throw new Error('No transaction received from backend');
      }

      const tx = Transaction.from(Buffer.from(serializedTx, 'base64'));
      const signedTx = await signTransaction(tx);

      const finalizeResponse = await fetch(`${API_BASE_URL}/api/user/claim/finalize`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          signedTransaction: signedTx.serialize().toString('base64'),
          walletAddress: publicKey.toString(),
          amount
        })
      });

      if (!finalizeResponse.ok) {
        const error = await finalizeResponse.json();
        throw new Error(error.error || 'Failed to finalize claim');
      }

      const finalizeResult = await finalizeResponse.json();
      if (finalizeResult.success) {
        onSuccess?.(finalizeResult);
        window.dispatchEvent(new CustomEvent('bux:balanceUpdated', {
          detail: {
            newBalance: finalizeResult.newBalance,
            unclaimedAmount: finalizeResult.unclaimedAmount
          }
        }));
      } else {
        throw new Error('Claim finalization failed');
      }
    } catch (error) {
      console.error('Claim error:', error);
      onError?.(error instanceof Error ? error : new Error('Unknown claim error'));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <button
      onClick={handleClaim}
      disabled={disabled || !connected || amount <= 0 || isLoading}
      className={className}
    >
      {children || (isLoading ? 'Claiming...' : `Claim ${TOKEN_SYMBOL}`)}
    </button>
  );
};

export default BuxClaimButton;
