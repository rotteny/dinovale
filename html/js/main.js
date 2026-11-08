// Tema (padrão claro) e menu compacto no celular.
(function () {
  var raiz = document.documentElement;
  var tema = document.querySelector('.tema');
  var menuBtn = document.querySelector('.menu-btn');
  var menu = document.getElementById('menu');

  function aplicarTema(escuro) {
    if (escuro) raiz.dataset.tema = 'escuro'; else delete raiz.dataset.tema;
    tema.setAttribute('aria-pressed', String(escuro));
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', escuro ? '#0A1D12' : '#0E4527');
  }
  aplicarTema(raiz.dataset.tema === 'escuro');
  tema.addEventListener('click', function () {
    var escuro = raiz.dataset.tema !== 'escuro';
    aplicarTema(escuro);
    try { localStorage.setItem('dv-tema', escuro ? 'escuro' : 'claro'); } catch (e) {}
  });

  function menu_(aberto) {
    menu.classList.toggle('aberto', aberto);
    menuBtn.setAttribute('aria-expanded', String(aberto));
    menuBtn.setAttribute('aria-label', aberto ? 'Fechar menu' : 'Abrir menu');
  }
  menuBtn.addEventListener('click', function () { menu_(!menu.classList.contains('aberto')); });
  menu.addEventListener('click', function (e) { if (e.target.tagName === 'A') menu_(false); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && menu.classList.contains('aberto')) { menu_(false); menuBtn.focus(); }
  });
})();

// Parallax leve do hero: camadas do menu do jogo, deslocadas em pixels inteiros do jogo.
(function () {
  var moldura = document.querySelector('[data-parallax]');
  if (!moldura) return;
  var camadas = Array.prototype.slice.call(moldura.querySelectorAll('.camada'));
  var reduz = window.matchMedia('(prefers-reduced-motion: reduce)');
  var visivel = true, ponteiro = 0, atual = 0, ultimo = [];

  function escala() { return parseInt(getComputedStyle(document.documentElement).getPropertyValue('--z'), 10) || 2; }
  function zerar() { camadas.forEach(function (c) { c.style.transform = ''; }); ultimo = []; }

  moldura.addEventListener('pointermove', function (e) {
    var r = moldura.getBoundingClientRect();
    ponteiro = Math.max(-1, Math.min(1, ((e.clientX - r.left) / r.width) * 2 - 1));
  });
  moldura.addEventListener('pointerleave', function () { ponteiro = 0; });
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (es) { visivel = es[0].isIntersecting; }).observe(moldura);
  }

  function quadro(t) {
    if (reduz.matches) { zerar(); } else if (visivel && !document.hidden) {
      atual += ((Math.sin(t / 5000) * 0.5 + ponteiro * 0.5) - atual) * 0.05;
      var z = escala();
      camadas.forEach(function (c, i) {
        var d = Math.round(-atual * parseFloat(c.dataset.fator) * 16) * z;
        if (ultimo[i] !== d) { c.style.transform = 'translateX(' + d + 'px)'; ultimo[i] = d; }
      });
    }
    requestAnimationFrame(quadro);
  }
  requestAnimationFrame(quadro);
})();

// Copiar o código Pix, com alternativa quando a clipboard não está disponível.
(function () {
  var botao = document.querySelector('[data-copiar]');
  if (!botao) return;
  var campo = document.getElementById(botao.dataset.copiar);
  var status = document.querySelector('.pix-status');
  var timer;
  campo.addEventListener('focus', function () { campo.select(); });
  function avisar(msg) {
    status.textContent = msg;
    clearTimeout(timer);
    timer = setTimeout(function () { status.textContent = ''; }, 3500);
  }
  function selecionar() {
    campo.focus(); campo.select();
    var ok = false;
    try { ok = document.execCommand('copy'); } catch (e) {}
    avisar(ok ? 'Copiado!' : 'Texto selecionado: use Ctrl+C ou o menu de copiar.');
  }
  botao.addEventListener('click', function () {
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(campo.value).then(function () { avisar('Copiado!'); }, selecionar);
    } else { selecionar(); }
  });
})();
