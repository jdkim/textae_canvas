import { Controller } from "@hotwired/stimulus"

// Draw arrows connecting child cards to their parent card vertically.
export default class extends Controller {
  static targets = ["svg"]

  // Private fields
  #drawArrowsBound
  #markerId = "history-arrow-head"
  #startX = 32
  #curveOffset = 40

  connect() {
    this.#drawArrows()
    this.#drawArrowsBound = this.#drawArrows.bind(this)
    window.addEventListener("resize", this.#drawArrowsBound)
  }

  disconnect() {
    window.removeEventListener("resize", this.#drawArrowsBound)
  }

  // ================= Private methods =================
  #drawArrows() {
    const svg = this.svgTarget
    if (!svg) return

    this.#clearSvg(svg)
    const cardMap = this.#buildCardMap()
    const bbox = this.#setupSvgDimensions(svg)

    this.#ensureArrowMarker(svg)

    this.element.querySelectorAll(".history-card").forEach((card) => {
      this.#drawArrowForCard(card, cardMap, bbox, svg)
    })
  }

  #clearSvg(svg) {
    while (svg.firstChild) svg.removeChild(svg.firstChild)
  }

  #buildCardMap() {
    const cards = this.element.querySelectorAll(".history-card")
    const cardMap = new Map()
    cards.forEach((c) => {
      cardMap.set(c.dataset.uuid, c)
    })
    return cardMap
  }

  #setupSvgDimensions(svg) {
    const bbox = this.element.getBoundingClientRect()
    svg.setAttribute("width", bbox.width)
    svg.setAttribute("height", bbox.height)
    svg.setAttribute("viewBox", `0 0 ${bbox.width} ${bbox.height}`)
    return bbox
  }

  #ensureArrowMarker(svg) {
    if (svg.querySelector(`#${this.#markerId}`)) return

    const marker = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "marker"
    )
    marker.setAttribute("id", this.#markerId)
    marker.setAttribute("markerWidth", "6")
    marker.setAttribute("markerHeight", "6")
    marker.setAttribute("refX", "5")
    marker.setAttribute("refY", "3")
    marker.setAttribute("orient", "auto")

    const arrowPath = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "path"
    )
    arrowPath.setAttribute("d", "M0,0 L6,3 L0,6 Z")
    arrowPath.setAttribute("fill", "#555")
    marker.appendChild(arrowPath)

    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs")
    defs.appendChild(marker)
    svg.appendChild(defs)
  }

  #drawArrowForCard(card, cardMap, bbox, svg) {
    const parentUuid = card.dataset.parentUuid
    if (!parentUuid) return

    const parentCard = cardMap.get(parentUuid)
    if (!parentCard) return

    const childRect = card.getBoundingClientRect()
    const parentRect = parentCard.getBoundingClientRect()

    const startY = parentRect.top + parentRect.height / 2 - bbox.top
    const endY = childRect.top + childRect.height / 2 - bbox.top
    const verticalGap = Math.abs(endY - startY)

    // Skip if cards are adjacent - straight arrow is rendered by helper
    if (verticalGap < 80) return

    const path = this.#createCurvedArrowPath(startY, endY)
    svg.appendChild(path)
  }

  #createCurvedArrowPath(startY, endY) {
    const startX = this.#startX // left edge margin
    const curveX = startX - this.#curveOffset // curve outward to the left
    const pathData = `M ${startX} ${startY} C ${curveX} ${startY}, ${curveX} ${endY}, ${startX} ${endY}`

    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("d", pathData)
    path.setAttribute("fill", "none")
    path.setAttribute("stroke", "#555")
    path.setAttribute("stroke-width", "1.2")
    path.setAttribute("marker-end", `url(#${this.#markerId})`)

    return path
  }
}
