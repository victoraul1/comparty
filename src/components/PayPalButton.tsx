'use client';

import { PayPalScriptProvider, PayPalButtons } from '@paypal/react-paypal-js';
import { useState, useEffect } from 'react';
import axios from 'axios';
import toast from 'react-hot-toast';

interface PayPalButtonProps {
  eventId: string;
  planCode: 'P50' | 'P100' | 'P200';
  amount: number;
  onSuccess?: (data: any) => void;
  onError?: (error: any) => void;
  onCancel?: () => void;
}

export default function PayPalButton({
  eventId,
  planCode,
  amount,
  onSuccess,
  onError,
  onCancel
}: PayPalButtonProps) {
  const [clientId, setClientId] = useState<string>('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Obtener configuración de PayPal
    axios.get('/api/payments/checkout')
      .then(response => {
        if (response.data.success) {
          setClientId(response.data.data.clientId);
        }
      })
      .catch(error => {
        console.error('Error obteniendo configuración de PayPal:', error);
        toast.error('Error al cargar PayPal');
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  if (loading || !clientId) {
    return (
      <div className="flex items-center justify-center p-4 bg-gray-100 rounded-lg">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span className="ml-3 text-gray-600">Cargando PayPal...</span>
      </div>
    );
  }

  return (
    <PayPalScriptProvider
      options={{
        clientId,
        currency: 'USD',
        intent: 'capture'
      }}
    >
      <div className="w-full">
        <PayPalButtons
          style={{
            layout: 'vertical',
            color: 'blue',
            shape: 'rect',
            label: 'pay'
          }}
          createOrder={async (data, actions) => {
            try {
              const token = localStorage.getItem('token');
              const response = await axios.post(
                '/api/payments/checkout',
                { eventId, planCode },
                {
                  headers: {
                    Authorization: `Bearer ${token}`
                  }
                }
              );

              if (response.data.success) {
                return response.data.data.orderId;
              }
              throw new Error('No se pudo crear la orden');
            } catch (error) {
              console.error('Error creando orden:', error);
              toast.error('Error al crear la orden de pago');
              throw error;
            }
          }}
          onApprove={async (data, actions) => {
            try {
              const response = await axios.post('/api/payments/capture', {
                orderId: data.orderID
              });

              if (response.data.success) {
                toast.success('¡Pago completado exitosamente!');
                if (onSuccess) {
                  onSuccess(response.data.data);
                }
              }
            } catch (error) {
              console.error('Error capturando pago:', error);
              toast.error('Error al procesar el pago');
              if (onError) {
                onError(error);
              }
            }
          }}
          onCancel={() => {
            toast.info('Pago cancelado');
            if (onCancel) {
              onCancel();
            }
          }}
          onError={(error) => {
            console.error('Error de PayPal:', error);
            toast.error('Error en el proceso de pago');
            if (onError) {
              onError(error);
            }
          }}
        />
      </div>
    </PayPalScriptProvider>
  );
}