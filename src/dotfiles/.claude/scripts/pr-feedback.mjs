#!/usr/bin/env node
import { execFileSync } from 'node:child_process'

const PAGE_SIZE = 100
const MAX_BUFFER = 50 * 1024 * 1024

function sh(command, args) {
    return execFileSync(command, args, { encoding: 'utf8', maxBuffer: MAX_BUFFER })
}

function graphql(query, variables) {
    const args = ['api', 'graphql', '-f', `query=${query}`]
    for (const [name, value] of Object.entries(variables)) {
        if (value === undefined || value === null) continue
        args.push(Number.isInteger(value) ? '-F' : '-f', `${name}=${value}`)
    }

    const result = JSON.parse(sh('gh', args))
    if (result.errors?.length) {
        throw new Error(result.errors.map(({ message }) => message).join('; '))
    }
    return result.data
}

function currentRepo() {
    const { owner, name } = JSON.parse(sh('gh', ['repo', 'view', '--json', 'owner,name']))
    return { owner: owner.login, repo: name }
}

function currentPrNumber() {
    return JSON.parse(sh('gh', ['pr', 'view', '--json', 'number'])).number
}

function parsePrNumber(value) {
    if (value === undefined) return currentPrNumber()
    if (!/^[1-9][0-9]*$/.test(value)) throw new Error(`invalid PR number: ${value}`)
    return Number(value)
}

function collectRootConnection(query, key, variables) {
    const nodes = []
    let cursor

    do {
        const data = graphql(query, { ...variables, cursor })
        const pullRequest = data.repository.pullRequest
        if (!pullRequest) throw new Error(`pull request ${variables.number} not found`)
        const connection = pullRequest[key]
        nodes.push(...connection.nodes)
        cursor = connection.pageInfo.hasNextPage ? connection.pageInfo.endCursor : undefined
    } while (cursor)

    return nodes
}

function collectNodeComments(query, id) {
    const nodes = []
    let cursor

    do {
        const data = graphql(query, { id, cursor })
        if (!data.node) throw new Error(`GitHub node not found: ${id}`)
        const connection = data.node.comments
        nodes.push(...connection.nodes)
        cursor = connection.pageInfo.hasNextPage ? connection.pageInfo.endCursor : undefined
    } while (cursor)

    return { nodes }
}

const COMMENT_FIELDS = `
    id
    author { login __typename }
    body
    createdAt
    url
`

// No diffHunk: `path` + `line` locate the comment, and the hunks dominated the
// payload (one anchored to a reformatted markdown table carried KBs of table).
const INLINE_COMMENT_FIELDS = `
    ${COMMENT_FIELDS}
    path
    line
    originalLine
`

const COMMENTS_QUERY = `
query($owner:String!,$repo:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      comments(first:${PAGE_SIZE},after:$cursor){
        nodes { ${COMMENT_FIELDS} }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}`

// State and summary body only. Inline comments come from reviewThreads below,
// which carry the same comments plus isResolved / isOutdated.
const REVIEWS_QUERY = `
query($owner:String!,$repo:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      reviews(first:${PAGE_SIZE},after:$cursor){
        nodes { author { login __typename } state body submittedAt }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}`

const THREADS_QUERY = `
query($owner:String!,$repo:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      reviewThreads(first:${PAGE_SIZE},after:$cursor){
        nodes { id isResolved isOutdated }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}`

const THREAD_COMMENTS_QUERY = `
query($id:ID!,$cursor:String){
  node(id:$id){
    ... on PullRequestReviewThread {
      comments(first:${PAGE_SIZE},after:$cursor){
        nodes { ${INLINE_COMMENT_FIELDS} }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}`

try {
    const cliArgs = process.argv.slice(2)
    const unknownFlag = cliArgs.find((arg) => arg.startsWith('-'))
    if (unknownFlag) throw new Error(`unknown flag: ${unknownFlag} (usage: pr-feedback.mjs [PR_NUMBER])`)

    const [prArg] = cliArgs
    const number = parsePrNumber(prArg)
    const { owner, repo } = currentRepo()
    const variables = { owner, repo, number }

    // GitHub Apps (semanticdiff, cypress, ...) author as __typename Bot; their
    // status dumps can dwarf the human feedback, so they are always dropped.
    // Bot output, when genuinely needed, comes straight from gh instead.
    const isBot = (item) => item.author?.__typename === 'Bot'

    const comments = collectRootConnection(COMMENTS_QUERY, 'comments', variables)
    const reviews = collectRootConnection(REVIEWS_QUERY, 'reviews', variables)
    const omittedBots = {
        comments: comments.filter(isBot).length,
        reviews: reviews.filter(isBot).length,
    }
    const humanComments = comments.filter((item) => !isBot(item))
    const humanReviews = reviews.filter((item) => !isBot(item))

    const reviewThreads = collectRootConnection(THREADS_QUERY, 'reviewThreads', variables)
    for (const thread of reviewThreads) {
        // Thread comments are never bot-filtered: bot-authored inline threads
        // (e.g. Copilot review comments) are code-anchored feedback, not status noise.
        thread.comments = collectNodeComments(THREAD_COMMENTS_QUERY, thread.id)
    }

    const pullRequest = {
        number,
        comments: { nodes: humanComments },
        reviews: { nodes: humanReviews },
        reviewThreads: { nodes: reviewThreads },
    }
    if (omittedBots.comments || omittedBots.reviews) {
        pullRequest.botFeedbackOmitted = {
            ...omittedBots,
            note: 'bot-authored items hidden; fetch them with gh directly if needed',
        }
    }
    process.stdout.write(`${JSON.stringify({ data: { repository: { pullRequest } } }, null, 2)}\n`)
} catch (error) {
    console.error((error.stderr || error.message).trim())
    process.exit(1)
}
