// Seleccionamos todos los elementos que tengan la clase 'revelar'
const elementosARevelar = document.querySelectorAll('.revelar');

// Función que detecta el scroll
function revelarScroll() {
    // Para cada elemento que queremos animar...
    for (let i = 0; i < elementosARevelar.length; i++) {
        // Obtenemos el alto de la pantalla
        let alturaVentana = window.innerHeight;
        // Obtenemos a qué distancia está el elemento de la parte superior de la pantalla
        let distanciaElemento = elementosARevelar[i].getBoundingClientRect().top;
        // Un punto imaginario donde queremos que se active (150px antes de que toque abajo)
        let puntoDeRevelado = 150;

        // Si el elemento ya entró en el área visible...
        if (distanciaElemento < alturaVentana - puntoDeRevelado) {
            elementosARevelar[i].classList.add('activo'); // Le ponemos la clase activo (aparece)
        }
    }
}

// Le decimos al navegador que ejecute la función cada vez que el usuario mueve la rueda del mouse o el dedo en el celular
window.addEventListener('scroll', revelarScroll);

// Ejecutamos la función una vez ni bien carga la página, por si algún elemento ya está a la vista desde el principio
revelarScroll();


// --- ANIMACIÓN DE CONTADORES (NÚMEROS QUE SUBEN) ---
const contadores = document.querySelectorAll('.contador');

// IntersectionObserver detecta exactamente cuándo un elemento aparece en la pantalla
const observarContadores = new IntersectionObserver((entradas, observador) => {
    entradas.forEach(entrada => {
        // Si la sección de números ya es visible en la pantalla...
        if (entrada.isIntersecting) {
            const contador = entrada.target;
            
            const actualizarContador = () => {
                const objetivo = +contador.getAttribute('data-target'); // El número final
                const actual = +contador.innerText; // El número donde está ahora
                
                // Calculamos a qué velocidad sube (200 es fluido)
                const incremento = objetivo / 200;
                
                if (actual < objetivo) {
                    contador.innerText = Math.ceil(actual + incremento);
                    setTimeout(actualizarContador, 20); // Se repite cada 20 milisegundos
                } else {
                    contador.innerText = objetivo; // Aseguramos que termine en el número exacto
                }
            };
            
            actualizarContador();
            // Le decimos al observador que deje de mirar, para que la animación se haga solo una vez
            observador.unobserve(contador); 
        }
    });
});

// Le asignamos el observador a cada uno de nuestros números
contadores.forEach(contador => {
    observarContadores.observe(contador);
});