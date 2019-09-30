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
  }
}
