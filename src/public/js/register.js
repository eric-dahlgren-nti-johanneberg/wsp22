function safeify(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const winnerSelect = document.getElementById("winner");
const loserSelect = document.getElementById("loser");

let users = [];

const updateLosers = () => {
  const selectedUser = parseInt(winnerSelect.value);
  const avalible = users.filter((u) => u.id !== selectedUser);
  const options = avalible.map(
    (u) => `<option value="${u.id}">${u.username} - ${u.elo} ELO</option>`
  );
  loserSelect.innerHTML = `${options}`;
  loserSelect.disabled = false;
};

winnerSelect.onchange = updateLosers;

const fetchUsers = async () => {
  fetch("/api/users")
    .then((res) => res.json())
    .then((json) => {
      users = json;
      const options = json.map(
        (u) => `<option value="${u.id}">${u.username} - ${u.elo} ELO</option>`
      );
      const defaultOption =
        '<option disabled="true" selected="true">Välj användare</option>';
      winnerSelect.innerHTML = `${[defaultOption, ...options].join()}`;
    });
};

fetchUsers();
