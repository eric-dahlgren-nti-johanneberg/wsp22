function safeify(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const container = document.querySelector("#leaderboard");

fetch("/api/users")
  .then((res) => res.json())
  .then((users) => {
    users.forEach((user, index) => {
      const el = document.createElement("a");
      el.href = `/user/${user.id}`;
      el.className = "flex flex-row gap-2 p-1";

      el.innerHTML = `
        <code>${index + 1}</code>
        <p>${safeify(user.elo)}</p>
        <p>${safeify(user.username)}</p>
      `;

      container.appendChild(el);
    });
  });
