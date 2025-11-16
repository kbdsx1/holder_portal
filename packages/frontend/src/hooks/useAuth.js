import { useContext } from 'react';
import { UserContext } from '../contexts/UserContext';

export const useAuth = () => {
  const { user, setUser } = useContext(UserContext);

  return {
    user,
    isAuthenticated: !!user,
    setUser
  };
}; 