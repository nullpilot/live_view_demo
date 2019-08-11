import LiveSocket from "phoenix_live_view"

export default class LiveSocketExt extends LiveSocket {
  bindTopLevelEvents() {
    super.bindTopLevelEvents()
    this.bindMouse()
  }

  bindMouse() {
    super.bindTargetable({
      touchstart: "touchstart",
      touchend: "touchend",
      mousedown: "mousedown",
      mouseup: "mouseup"
    }, (e, type, view, targetEl, phxEvent, phxTarget) => {
      const boundingBox = targetEl.getBoundingClientRect()
      const x = e.clientX - boundingBox.x
      const y = e.clientY - boundingBox.y

      e.preventDefault();

      if(phxEvent === "drawstart") {
        this.drawing = true
      } else {
        this.drawing = false
      }

      view.pushWithReply("event", {
        type: type,
        event: phxEvent,
        value: { x, y }
      })
    })

    super.bindTargetable({
      touchmove: "touchmove",
      mousemove: "mousemove"
    }, (e, type, view, targetEl, phxEvent, phxTarget) => {
      const boundingBox = targetEl.getBoundingClientRect()
      const x = e.clientX - boundingBox.x
      const y = e.clientY - boundingBox.y

      e.preventDefault()

      if(this.drawing) {
        view.pushWithReply("event", {
          type: type,
          event: phxEvent,
          value: { x, y }
        })
      }
    })
  }
}
