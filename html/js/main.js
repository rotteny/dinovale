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
