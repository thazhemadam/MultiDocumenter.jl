// custom search widget
(function() {
    const flexsearchIdx = new FlexSearch.Document({
        document: {
            id: 'id',
            store: ['title', 'pagetitle', 'ref'],
            index: [
                {
                    field: 'content',
                    tokenize: 'forward',
                    minlength: 3,
                    resolution: 9
                }
            ]
        },
        encoder: 'simple',
        fastupdate: false,
        optimize: true,
        context: true,
    });

    let importDone = null

    function loadIndex(flexsearchIdx) {
        const input = document.getElementById('search-input')
        input.setAttribute('placeholder', 'Loading...')
        importDone = false
        const keys = ['content.cfg', 'content.ctx', 'content.map', 'reg', 'store']
        for (const key of keys) {
            fetch('/search-data/' + key + '.json').then(r => {
                if (r.ok) {
                    r.json().then(idx => {
                        flexsearchIdx.import(key, idx)
                        if (key === keys[keys.length - 1]) {
                            setTimeout(() => {
                                importDone = true
                                input.setAttribute('placeholder', 'Search...')
                            }, 100)
                        }
                    })
                } else {
                    input.setAttribute('placeholder', 'Error loading search index.')
                }
            })
        }
    }

    function registerSearchListener() {
        const input = document.getElementById('search-input')
        const suggestions = document.getElementById('search-result-container')

        let lastQuery = ''

        function runSearch() {
            if (importDone === null) {
                loadIndex(flexsearchIdx)
            } else if (importDone === false) {
                return
            }
            const query = input.value

            if (flexsearchIdx && query !== lastQuery) {
                lastQuery = query

                console.time('search')
                let results = flexsearchIdx.search(query, {
                    limit: 10,
                    enrich: true
                })
                console.timeEnd('search')

                if (results.length > 0) {
                    buildResults(results[0].result.map(r => r.doc))
                } else {
                    suggestions.classList.add('hidden')
                }
            }
        }

        input.addEventListener('keyup', ev => {
            runSearch()
        })

        input.addEventListener('keydown', ev => {
            if (ev.key === 'ArrowDown') {
                suggestions.firstChild.firstChild.focus()
                ev.preventDefault()
                return
            } else if (ev.key === 'ArrowUp') {
                suggestions.lastChild.firstChild.focus()
                ev.preventDefault()
                return
            }
        })

        suggestions.addEventListener('keydown', ev => {
            if (ev.target.dataset.index !== undefined) {
                const li = ev.target.parentElement
                if (ev.key === 'ArrowDown') {
                    const el = li.nextSibling
                    if (el) {
                        el.firstChild.focus()
                        ev.preventDefault()
                    } else {
                        input.focus()
                    }
                } else if (ev.key === 'ArrowUp') {
                    const el = li.previousSibling
                    if (el) {
                        el.firstChild.focus()
                        ev.preventDefault()
                    } else {
                        input.focus()
                    }
                }
            }
        })

        input.addEventListener('focus', ev => {
            runSearch()
        })
    }

    function buildResults(results) {
        const suggestions = document.getElementById('search-result-container')

        suggestions.classList.remove('hidden')

        console.log(results)

        const children = results.slice(0, 9).map((r, i) => {
            const entry = document.createElement('li')
            entry.classList.add('suggestion')
            const link = document.createElement('a')
            link.setAttribute('href', r.ref)
            link.dataset.index = i
            const page = document.createElement('span')
            page.classList.add('page-title')
            page.innerText = r.pagetitle
            const section = document.createElement('span')
            section.innerText = ' > ' + r.title
            section.classList.add('section-title')
            link.appendChild(page)
            link.appendChild(section)
            entry.appendChild(link)
            return entry
        })
        suggestions.replaceChildren(
            ...children
        )
    }

    function initialize() {
        registerSearchListener()

        document.body.addEventListener('keydown', ev => {
            if (ev.key === '/') {
                document.getElementById('search-input').focus()
                ev.preventDefault()
            }
        })
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize)
    } else {
        initialize()
    };
})()