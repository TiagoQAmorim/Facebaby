(function () {
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.querySelector('.site-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });

    nav.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        nav.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  var showcase = document.getElementById('feature-showcase');
  var lightbox = document.getElementById('feature-lightbox');
  if (!showcase || !lightbox) return;

  var items = Array.prototype.slice.call(
    showcase.querySelectorAll('.feature-showcase__item')
  );
  if (!items.length) return;

  var slides = items.map(function (btn) {
    var img = btn.querySelector('img');
    var caption = btn.querySelector('.feature-showcase__caption');
    return {
      src: img ? img.getAttribute('src') : '',
      alt: btn.getAttribute('aria-label') || (caption ? caption.textContent : ''),
      caption: caption ? caption.textContent.trim() : '',
    };
  });

  var imgEl = document.getElementById('feature-lightbox-img');
  var captionEl = document.getElementById('feature-lightbox-caption');
  var current = 0;
  var lastFocus = null;

  function render(index) {
    current = (index + slides.length) % slides.length;
    var slide = slides[current];
    if (!slide || !imgEl || !captionEl) return;
    imgEl.src = slide.src;
    imgEl.alt = slide.alt;
    captionEl.textContent = slide.caption;
  }

  function openAt(index) {
    lastFocus = document.activeElement;
    render(index);
    lightbox.hidden = false;
    lightbox.setAttribute('aria-hidden', 'false');
    lightbox.classList.add('is-open');
    document.body.classList.add('lightbox-open');
    var closeBtn = lightbox.querySelector('.feature-lightbox__close');
    if (closeBtn) closeBtn.focus();
  }

  function closeLightbox() {
    lightbox.classList.remove('is-open');
    lightbox.hidden = true;
    lightbox.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('lightbox-open');
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }

  items.forEach(function (btn, index) {
    btn.addEventListener('click', function () {
      openAt(index);
    });
  });

  lightbox.querySelectorAll('[data-lightbox-close]').forEach(function (el) {
    el.addEventListener('click', closeLightbox);
  });

  var prevBtn = lightbox.querySelector('[data-lightbox-prev]');
  var nextBtn = lightbox.querySelector('[data-lightbox-next]');
  if (prevBtn) {
    prevBtn.addEventListener('click', function () {
      render(current - 1);
    });
  }
  if (nextBtn) {
    nextBtn.addEventListener('click', function () {
      render(current + 1);
    });
  }

  document.addEventListener('keydown', function (event) {
    if (lightbox.hidden) return;
    if (event.key === 'Escape') {
      event.preventDefault();
      closeLightbox();
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      render(current - 1);
    } else if (event.key === 'ArrowRight') {
      event.preventDefault();
      render(current + 1);
    }
  });
})();
