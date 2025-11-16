import { useWalletModal } from '@solana/wallet-adapter-react-ui';
import { useWallet } from '@solana/wallet-adapter-react';
import { XMarkIcon } from '@heroicons/react/24/outline';

export const WalletModalButton = () => {
  const { visible, setVisible } = useWalletModal();
  const { connected, connecting, disconnect } = useWallet();

  const handleClose = () => {
    setVisible(false);
  };

  const handleClick = () => {
    if (connected) {
      disconnect();
    } else {
      setVisible(true);
    }
  };

  return (
    <div className="relative">
      <button
        onClick={handleClick}
        disabled={connecting}
        className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50"
      >
        {connecting ? 'Connecting...' : connected ? 'Disconnect Wallet' : 'Connect Wallet'}
      </button>
      {visible && (
        <button
          onClick={handleClose}
          className="absolute -top-2 -right-2 p-1 bg-gray-800 rounded-full hover:bg-gray-700 transition-colors"
          aria-label="Close"
        >
          <XMarkIcon className="h-4 w-4 text-gray-400" />
        </button>
      )}
    </div>
  );
}; 