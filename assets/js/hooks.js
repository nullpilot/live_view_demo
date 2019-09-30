export default {
  ChatInput: {
    updated() {
      const input = this.el.querySelector("input[name=message]")

      input.value = "";
      input.focus();
    }
  },
  ChatMessage: {
    mounted() {
      const p = this.el.parentElement;
      p.scrollTop = p.clientHeight;
    }
  },
  Draw: {
    mounted() {
      const bind = this.el.addEventListener.bind(this.el);
      const push = pushCoords.bind(this);
      let drawing = false;

      bind("mousedown", event => {
        drawing = true;
        push("drawstart", event)
      })

      bind("mousemove", event => {
        if(drawing) {
          push("draw", event);
        }
      })

      bind("mouseup", event => {
        drawing = false;
        push("drawend", event)
      })

      bind("mouseleave", event => {
        drawing = false;
        push("drawend", event)
      })
    }
  }
}

function pushCoords(phxEvent, event) {
  this.__view.pushWithReply("event", {
    type: event.type,
    event: phxEvent,
    value: getCoords(event)
  })
}

function getCoords(event) {
  const el = event.target;
  const bBox = el.getBoundingClientRect()
  const x = event.clientX - bBox.x
  const y = event.clientY - bBox.y

  return {x, y}
}
