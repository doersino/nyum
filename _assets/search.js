const searchInput = document.querySelector("#search_input");
const searchOutput = document.querySelector("#search_output");

// asynchronously load search "index" (the search box will remain disabled until then)
let searchIndex;
fetch("search.json")
    .then(response => response.json())
    .then(data => {
        searchIndex = data;
        searchInput.removeAttribute("disabled");
    })
    .catch(error => {
        searchOutput.innerHTML = `<span class="error">${error}</span>`
    });

// search the "index" for a query string while assigning different weights depending on which parts of the json value the query appears in
function search(query) {
    const matches = (haystack, needle) => (haystack || "").toLowerCase().includes(needle.toLowerCase());

    let results = [];
    searchIndex.forEach(e => {
        let score = 0;
        if (matches(e.title, query)) {
            score += 10;
        }
        if (matches(e["original_title"], query)) {
            score += 6;
        }
        if (matches(e["description"], query)) {
            score += 5;
        }
        if (matches(e["category"], query)) {
            score += 3;
        }
        if (matches(e["author"], query)) {
            score += 3;
        }
        if (matches(e["htmlfile"], query)) {
            score += 1;
        }
        results.push({score: score, e: e});
    });

    // should be "a.score - b.score", but then we'd need to reverse afterwards
    return results.filter(r => r.score > 0).sort((a, b) => b.score - a.score).map(e => e.e);
}

function clearResults() {
    searchOutput.innerHTML = "";
}

// render a subset of the search index in the results/output pane
function showResults(results) {
    const code = results.map(e => {
        return `<h3><span class="icons">`
            + (e.favorite ? `<img src="assets/tabler-icons/tabler-icon-star.svg"> ` : ``)
            + (e.spicy ? `<img src="assets/tabler-icons/tabler-icon-flame.svg"> ` : ``)
            + ((e.veggie || e.vegan) ? `` : `<img src="assets/tabler-icons/tabler-icon-bone.svg"> `)
            + (e.vegan ? `<img src="assets/tabler-icons/tabler-icon-leaf.svg"> ` : ``)
            + `</span><a href="${e.htmlfile}">${e.title}</a> `
            + (e.original_title ? `<em>${e.original_title}</em>` : ``)
            + `</h3>`;
    });

    searchOutput.innerHTML = code.join("");
}

// clear results, search if the search bar isn't empty, and display results
searchInput.addEventListener('input', e => {
    clearResults();
    if (searchInput.value) {
        const results = search(searchInput.value);
        showResults(results);
    }
});
