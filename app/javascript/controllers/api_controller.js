import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['params']
  static values = {
    url: String
  }

  buildQueryURL() {
    const url = new URL(this.urlValue);
    url.pathname = `${url.pathname}.turbo_stream`;
    this.paramsTargets.forEach((el) => {
      this.setSearchParams(url.searchParams, el);
    });
    return url.toString();
  }

  setSearchParams(searchParams, el) {
    if (el.dataset.valueType === 'childCount') {
      const selectSrc = el.dataset.valueTargetSrc === '_top' ? document : this;
      const srcEl = selectSrc.querySelector(el.dataset.valueTarget);
      searchParams.set(el.dataset.key, srcEl.children.length);
    } else {
      searchParams.set(el.dataset.key, el.dataset.value);
    }
  }

  submit(evt) {
    evt.preventDefault();

    const url = this.buildQueryURL();
    if (!url) return;

    Turbo.visit(url);
  }
}
