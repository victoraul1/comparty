import Link from 'next/link';
import { Camera, Users, Sparkles, Clock, Shield, Download } from 'lucide-react';
import PricingPlans from '@/components/PricingPlans';

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-white to-gray-50">
      {/* Hero Section */}
      <section className="relative overflow-hidden">
        <div className="mx-auto max-w-7xl px-6 py-24 sm:py-32 lg:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <h1 className="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
              Las mejores fotos de tu evento,{' '}
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-purple-600">
                seleccionadas con IA
              </span>
            </h1>
            <p className="mt-6 text-lg leading-8 text-gray-600">
              Invita a tus invitados a subir fotos. Comparty selecciona automáticamente 
              las mejores 5 de cada uno usando inteligencia artificial. Sin esfuerzo, 
              sin desorden, solo momentos memorables.
            </p>
            <div className="mt-10 flex items-center justify-center gap-x-6">
              <Link
                href="/register"
                className="rounded-md bg-blue-600 px-6 py-3 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600"
              >
                Crear mi primer evento
              </Link>
              <Link
                href="#how-it-works"
                className="text-sm font-semibold leading-6 text-gray-900"
              >
                ¿Cómo funciona? <span aria-hidden="true">→</span>
              </Link>
            </div>
          </div>
          
          {/* Decorative gradient */}
          <div className="absolute inset-x-0 -top-40 -z-10 transform-gpu overflow-hidden blur-3xl sm:-top-80">
            <div className="relative left-[calc(50%-11rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 rotate-[30deg] bg-gradient-to-tr from-blue-400 to-purple-400 opacity-30 sm:left-[calc(50%-30rem)] sm:w-[72.1875rem]" />
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-base font-semibold leading-7 text-blue-600">
              Tecnología avanzada
            </h2>
            <p className="mt-2 text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
              Todo lo que necesitas para un álbum perfecto
            </p>
          </div>
          
          <div className="mx-auto mt-16 max-w-2xl sm:mt-20 lg:mt-24 lg:max-w-none">
            <dl className="grid max-w-xl grid-cols-1 gap-x-8 gap-y-16 lg:max-w-none lg:grid-cols-3">
              <div className="flex flex-col">
                <dt className="flex items-center gap-x-3 text-base font-semibold leading-7 text-gray-900">
                  <Sparkles className="h-5 w-5 flex-none text-purple-600" />
                  Selección con IA GPT-4
                </dt>
                <dd className="mt-4 flex flex-auto flex-col text-base leading-7 text-gray-600">
                  <p className="flex-auto">
                    Nuestro sistema analiza composición, emociones, nitidez y relevancia 
                    para elegir las mejores 5 fotos de cada invitado automáticamente.
                  </p>
                </dd>
              </div>
              
              <div className="flex flex-col">
                <dt className="flex items-center gap-x-3 text-base font-semibold leading-7 text-gray-900">
                  <Users className="h-5 w-5 flex-none text-blue-600" />
                  Colaboración sencilla
                </dt>
                <dd className="mt-4 flex flex-auto flex-col text-base leading-7 text-gray-600">
                  <p className="flex-auto">
                    Envía un simple link a tus invitados. No necesitan registrarse, 
                    solo subir sus fotos durante la ventana de tiempo que definas.
                  </p>
                </dd>
              </div>
              
              <div className="flex flex-col">
                <dt className="flex items-center gap-x-3 text-base font-semibold leading-7 text-gray-900">
                  <Shield className="h-5 w-5 flex-none text-green-600" />
                  Privacidad garantizada
                </dt>
                <dd className="mt-4 flex flex-auto flex-col text-base leading-7 text-gray-600">
                  <p className="flex-auto">
                    Marca de agua automática, eliminación de datos EXIF y control 
                    total sobre quién puede ver y descargar las fotos.
                  </p>
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </section>

      {/* How it Works */}
      <section id="how-it-works" className="bg-white py-24 sm:py-32">
        <div className="mx-auto max-w-7xl px-6 lg:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
              Tan simple como 1, 2, 3
            </h2>
            <p className="mt-4 text-lg text-gray-600">
              Crea álbumes memorables sin el trabajo tedioso
            </p>
          </div>
          
          <div className="mx-auto mt-16 max-w-2xl sm:mt-20 lg:mt-24 lg:max-w-4xl">
            <dl className="grid max-w-xl grid-cols-1 gap-y-10 gap-x-8 lg:max-w-none lg:grid-cols-3 lg:gap-y-16">
              <div className="relative pl-16">
                <dt className="text-base font-semibold leading-7 text-gray-900">
                  <div className="absolute top-0 left-0 flex h-10 w-10 items-center justify-center rounded-lg bg-blue-600">
                    <span className="text-white font-bold">1</span>
                  </div>
                  Crea tu evento
                </dt>
                <dd className="mt-2 text-base leading-7 text-gray-600">
                  Elige un plan, configura tu evento y genera links de invitación únicos.
                </dd>
              </div>
              
              <div className="relative pl-16">
                <dt className="text-base font-semibold leading-7 text-gray-900">
                  <div className="absolute top-0 left-0 flex h-10 w-10 items-center justify-center rounded-lg bg-blue-600">
                    <span className="text-white font-bold">2</span>
                  </div>
                  Invitados suben fotos
                </dt>
                <dd className="mt-2 text-base leading-7 text-gray-600">
                  Comparte el link con tus invitados. Ellos suben sus fotos sin registro.
                </dd>
              </div>
              
              <div className="relative pl-16">
                <dt className="text-base font-semibold leading-7 text-gray-900">
                  <div className="absolute top-0 left-0 flex h-10 w-10 items-center justify-center rounded-lg bg-blue-600">
                    <span className="text-white font-bold">3</span>
                  </div>
                  IA selecciona lo mejor
                </dt>
                <dd className="mt-2 text-base leading-7 text-gray-600">
                  Nuestra IA analiza y elige las mejores 5 fotos de cada invitado. Tú moderas y compartes.
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section className="bg-gray-50">
        <PricingPlans />
      </section>

      {/* CTA Section */}
      <section className="bg-blue-600">
        <div className="px-6 py-24 sm:px-6 sm:py-32 lg:px-8">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight text-white sm:text-4xl">
              ¿Listo para crear tu primer álbum inteligente?
            </h2>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-8 text-blue-100">
              Únete a miles de hosts que ya confían en Comparty para capturar 
              los mejores momentos de sus eventos.
            </p>
            <div className="mt-10 flex items-center justify-center gap-x-6">
              <Link
                href="/register"
                className="rounded-md bg-white px-6 py-3 text-sm font-semibold text-blue-600 shadow-sm hover:bg-blue-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
              >
                Empezar gratis
              </Link>
              <Link
                href="/demo"
                className="text-sm font-semibold leading-6 text-white"
              >
                Ver demo <span aria-hidden="true">→</span>
              </Link>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
