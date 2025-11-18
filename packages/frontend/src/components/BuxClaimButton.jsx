import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useWallet } from '@solana/wallet-adapter-react';
import { useWalletModal } from '@solana/wallet-adapter-react-ui';
import { Transaction } from '@solana/web3.js';
import { Buffer } from 'buffer';
import { API_BASE_URL, TOKEN_SYMBOL } from '../config.js';

const BuxClaimButton = ({ 
  amount, 
  onSuccess, 
  onError,
  disabled,
  className,
  children,
  unclaimedAmount = 0
}) => {
  const { publicKey, signTransaction, connected } = useWallet();
  const { setVisible } = useWalletModal();
  const [isLoading, setIsLoading] = useState(false);
  const pendingClaimRef = useRef(false);

  const processClaim = useCallback(async () => {
    if (!publicKey || !signTransaction) {
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
  }, [publicKey, signTransaction, amount, onSuccess, onError]);

  // If wallet gets connected after we opened the modal, proceed with claim
  useEffect(() => {
    if (connected && publicKey && signTransaction && pendingClaimRef.current && amount > 0) {
      pendingClaimRef.current = false;
      processClaim();
    }
  }, [connected, publicKey, signTransaction, amount, processClaim]);

  const handleClaim = async () => {
    // If wallet is not connected, prompt user to connect
    if (!connected || !publicKey || !signTransaction) {
      pendingClaimRef.current = true;
      setVisible(true);
      return;
    }

    processClaim();
  };

  // Enable button if Discord is connected (unclaimedAmount > 0) and amount > 0
  // Wallet connection will be prompted on click if not connected
  const isEnabled = !disabled && amount > 0 && unclaimedAmount > 0 && !isLoading;

  return (
    <button
      onClick={handleClaim}
      disabled={!isEnabled}
      className={className}
    >
      {children || (isLoading ? 'Claiming...' : `Claim ${TOKEN_SYMBOL}`)}
    </button>
  );
};

export default BuxClaimButton;
