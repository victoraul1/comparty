import { useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import axios from 'axios';
import toast from 'react-hot-toast';

interface CheckoutOptions {
  eventId: string;
  planCode: 'FREE' | 'P50' | 'P100' | 'P200';
}

interface ExtensionOptions {
  eventId: string;
}

export function usePayPal() {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  // Iniciar checkout para un plan
  const initiateCheckout = useCallback(async (options: CheckoutOptions) => {
    setIsLoading(true);
    setError(null);

    try {
      const token = localStorage.getItem('token');
      const response = await axios.post(
        '/api/payments/checkout',
        options,
        {
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      );

      if (response.data.success) {
        const { approvalUrl, redirectUrl, message } = response.data.data;
        
        toast.success(message);

        if (approvalUrl) {
          // Redirigir a PayPal
          window.location.href = approvalUrl;
        } else if (redirectUrl) {
          // Plan gratuito, redirigir directamente
          router.push(redirectUrl);
        }
      }
    } catch (err: any) {
      const errorMessage = err.response?.data?.error || 'Error al procesar el pago';
      setError(errorMessage);
      toast.error(errorMessage);
    } finally {
      setIsLoading(false);
    }
  }, [router]);

  // Capturar pago después de la aprobación
  const capturePayment = useCallback(async (orderId: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await axios.post('/api/payments/capture', { orderId });

      if (response.data.success) {
        const { eventId, eventName } = response.data.data;
        toast.success(`¡Pago completado! Tu evento "${eventName}" está activo.`);
        router.push(`/events/${eventId}/invitations`);
        return response.data.data;
      }
    } catch (err: any) {
      const errorMessage = err.response?.data?.error || 'Error al capturar el pago';
      setError(errorMessage);
      toast.error(errorMessage);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, [router]);

  // Iniciar suscripción para extensión
  const initiateExtension = useCallback(async (options: ExtensionOptions) => {
    setIsLoading(true);
    setError(null);

    try {
      const token = localStorage.getItem('token');
      const response = await axios.post(
        '/api/extensions/checkout',
        options,
        {
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      );

      if (response.data.success) {
        const { approvalUrl, message } = response.data.data;
        
        toast.success(message);

        if (approvalUrl) {
          // Redirigir a PayPal para aprobar suscripción
          window.location.href = approvalUrl;
        }
      }
    } catch (err: any) {
      const errorMessage = err.response?.data?.error || 'Error al procesar la extensión';
      setError(errorMessage);
      toast.error(errorMessage);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Verificar estado de extensión
  const checkExtensionStatus = useCallback(async (eventId: string) => {
    try {
      const token = localStorage.getItem('token');
      const response = await axios.get(
        `/api/extensions/checkout?eventId=${eventId}`,
        {
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      );

      return response.data.data;
    } catch (err) {
      console.error('Error verificando extensión:', err);
      return null;
    }
  }, []);

  // Cancelar suscripción
  const cancelSubscription = useCallback(async (subscriptionId: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const token = localStorage.getItem('token');
      const response = await axios.delete(
        `/api/extensions/${subscriptionId}`,
        {
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      );

      if (response.data.success) {
        toast.success('Suscripción cancelada exitosamente');
        return true;
      }
    } catch (err: any) {
      const errorMessage = err.response?.data?.error || 'Error al cancelar la suscripción';
      setError(errorMessage);
      toast.error(errorMessage);
      return false;
    } finally {
      setIsLoading(false);
    }
  }, []);

  return {
    isLoading,
    error,
    initiateCheckout,
    capturePayment,
    initiateExtension,
    checkExtensionStatus,
    cancelSubscription
  };
}