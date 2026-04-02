/* ── Shared Navigation ── */
(function () {
  const page = location.pathname.split('/').pop() || 'index.html';

  /* ── NAV CSS ── */
  const css = document.createElement('style');
  css.textContent = `
.nav{position:fixed;top:0;left:0;right:0;z-index:100;background:rgba(17,17,17,.92);backdrop-filter:blur(20px);border-bottom:1px solid rgba(255,255,255,.05)}
.nav-inner{max-width:var(--max-w,1280px);margin:0 auto;padding:0 32px;display:flex;align-items:center;justify-content:space-between;height:72px}
.nav-logo{display:flex;align-items:center;gap:12px;text-decoration:none}
.nav-logo .mark{font-weight:900;font-size:28px;color:var(--accent);letter-spacing:-1px}
.nav-logo .wordmark{line-height:1.1}
.nav-logo .wordmark .sm{font-size:9px;font-weight:500;color:var(--t2);letter-spacing:2px;text-transform:uppercase}
.nav-logo .wordmark .lg{font-size:16px;font-weight:700;color:var(--white)}
.nav-links{display:flex;align-items:center;gap:32px}
.nav-links a{color:var(--t2);font-size:13px;font-weight:500;letter-spacing:.5px;text-transform:uppercase;transition:color .2s;text-decoration:none}
.nav-links a:hover,.nav-links a.active{color:var(--white)}
.nav-links .nav-score{color:var(--accent)!important;font-weight:700}
.nav-links .nav-score:hover{color:var(--accent-light)!important}
.nav-links .nav-login{background:var(--accent);color:#fff!important;padding:8px 16px;border-radius:8px;font-weight:700;font-size:12px;letter-spacing:.5px}
.nav-links .nav-login:hover{opacity:.9}
.nav-right{display:flex;align-items:center;gap:16px}
.nav-user{font-size:12px;color:var(--t2)}.nav-user a{color:var(--accent);cursor:pointer}
.user-email{font-size:11px;color:var(--t3);max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.logout-btn{background:var(--bg3);border:1px solid var(--t4);border-radius:6px;padding:6px 12px;color:var(--t2);font-family:'Outfit',sans-serif;font-size:11px;cursor:pointer;transition:all .2s}
.logout-btn:hover{border-color:var(--accent);color:var(--white)}
.nav-cart{position:relative;cursor:pointer;padding:8px}
.nav-cart svg{width:22px;height:22px;stroke:var(--t2);fill:none;stroke-width:1.5;transition:stroke .2s}
.nav-cart:hover svg{stroke:var(--white)}
.cart-count{position:absolute;top:2px;right:0;background:var(--accent);color:var(--bg);font-size:10px;font-weight:700;width:18px;height:18px;border-radius:50%;display:flex;align-items:center;justify-content:center}
.nav-mobile{display:none;cursor:pointer;padding:8px}
.nav-mobile svg{width:24px;height:24px;stroke:var(--white);fill:none;stroke-width:2}
@media(max-width:768px){.nav-links{display:none}.nav-mobile{display:block}.user-email{display:none}}
.mobile-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:199;display:none}
.mobile-overlay.open{display:block}
.mobile-menu{position:fixed;top:0;right:-100%;width:280px;height:100vh;background:var(--bg2);border-left:1px solid rgba(255,255,255,.06);z-index:200;transition:right .3s ease;padding:80px 32px 40px;display:flex;flex-direction:column;gap:0}
.mobile-menu.open{right:0}
.mobile-close{position:absolute;top:20px;right:20px;background:none;border:none;cursor:pointer;padding:8px}
.mobile-close svg{width:24px;height:24px;stroke:var(--t2);fill:none;stroke-width:2}
.mobile-menu a{display:block;padding:16px 0;color:var(--t2);font-size:15px;font-weight:500;border-bottom:1px solid rgba(255,255,255,.04);transition:color .2s;text-decoration:none}
.mobile-menu a:hover,.mobile-menu a.active{color:var(--white)}
.mobile-menu .mobile-cart{display:flex;align-items:center;gap:10px;padding:16px 0;color:var(--t2);font-size:15px;font-weight:500;border-bottom:1px solid rgba(255,255,255,.04);cursor:pointer}
.mobile-menu .mobile-cart svg{width:20px;height:20px;stroke:currentColor;fill:none;stroke-width:1.5}
.mobile-menu .mobile-login{display:inline-block;background:var(--accent);color:#fff;padding:12px 24px;border-radius:8px;font-weight:700;font-size:13px;text-align:center;margin-top:16px;letter-spacing:.5px;text-decoration:none}
`;
  document.head.appendChild(css);

  /* ── Links ── */
  const links = [
    { href: 'index.html', text: 'Home' },
    { href: 'shop.html', text: 'Shop' },
    { href: 'supplements.html', text: 'Supplements' },
    { href: 'protocols.html', text: 'Protocols' },
    { href: 'about.html', text: 'About' },
    { href: 'partners.html', text: 'Partners' },
    { href: 'contact.html', text: 'Contact' },
  ];

  function activeClass(href) {
    return page === href ? ' class="active"' : '';
  }

  const desktopLinks = links.map(l => `<a href="${l.href}"${activeClass(l.href)}>${l.text}</a>`).join('');
  const mobileLinks = links.map(l => `<a href="${l.href}"${activeClass(l.href)}>${l.text}</a>`).join('\n  ');

  const cartSvg = '<svg viewBox="0 0 24 24"><path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/></svg>';

  /* ── Build HTML ── */
  const navHTML = `
<nav class="nav"><div class="nav-inner">
  <a href="index.html" class="nav-logo"><div class="mark">OH</div><div class="wordmark"><div class="sm">THE</div><div class="lg">Optimized Human</div></div></a>
  <div class="nav-links">
    ${desktopLinks}
    <a href="assessment.html" class="nav-score"${page === 'assessment.html' ? ' style="color:var(--accent)"' : ''}>OH Score&trade;</a>
    <a href="shop.html" class="nav-login" id="navLogin">LOG IN</a>
  </div>
  <div class="nav-right">
    <div class="nav-user" id="navUser" style="display:none"></div>
  </div>
  <div class="nav-cart" onclick="window.location.href='cart.html'">${cartSvg}<div class="cart-count" id="cartCount">0</div></div>
  <div class="nav-mobile" onclick="toggleMobileNav()">${'<svg viewBox="0 0 24 24"><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="18" x2="21" y2="18"/></svg>'}</div>
</div></nav>
<div class="mobile-overlay" id="mobileOverlay" onclick="toggleMobileNav()"></div>
<div class="mobile-menu" id="mobileMenu">
  <button class="mobile-close" onclick="toggleMobileNav()"><svg viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
  ${mobileLinks}
  <a href="assessment.html" style="color:var(--accent)">OH Score&trade;</a>
  <div class="mobile-cart" onclick="window.location.href='cart.html'">${cartSvg} Cart</div>
  <a href="shop.html" class="mobile-login" id="mobileLogin">LOG IN / SIGN UP</a>
</div>`;

  /* ── Inject ── */
  document.body.insertAdjacentHTML('afterbegin', navHTML);

  /* ── Mobile toggle ── */
  window.toggleMobileNav = function () {
    document.getElementById('mobileMenu').classList.toggle('open');
    document.getElementById('mobileOverlay').classList.toggle('open');
  };

  /* ── Alias for legacy pages ── */
  window.toggleMobileMenu = window.toggleMobileNav;
  window.toggleMobile = window.toggleMobileNav;
})();
