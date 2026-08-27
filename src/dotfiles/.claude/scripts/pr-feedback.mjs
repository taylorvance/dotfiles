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
    author { login }
    body
    createdAt
    url
`

const INLINE_COMMENT_FIELDS = `
    ${COMMENT_FIELDS}
    path
    line
    originalLine
    diffHunk
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

const REVIEWS_QUERY = `
query($owner:String!,$repo:String!,$number:Int!,$cursor:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$number){
      reviews(first:${PAGE_SIZE},after:$cursor){
        nodes { id author { login } state body submittedAt }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}`

const REVIEW_COMMENTS_QUERY = `
query($id:ID!,$cursor:String){
  node(id:$id){
    ... on PullRequestReview {
      comments(first:${PAGE_SIZE},after:$cursor){
        nodes { ${INLINE_COMMENT_FIELDS} }
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
    const [prArg] = process.argv.slice(2)
    const number = parsePrNumber(prArg)
    const { owner, repo } = currentRepo()
    const variables = { owner, repo, number }

    const comments = collectRootConnection(COMMENTS_QUERY, 'comments', variables)
    const reviews = collectRootConnection(REVIEWS_QUERY, 'reviews', variables)
    for (const review of reviews) {
        review.comments = collectNodeComments(REVIEW_COMMENTS_QUERY, review.id)
    }

    const reviewThreads = collectRootConnection(THREADS_QUERY, 'reviewThreads', variables)
    for (const thread of reviewThreads) {
        thread.comments = collectNodeComments(THREAD_COMMENTS_QUERY, thread.id)
    }

    const pullRequest = {
        number,
        comments: { nodes: comments },
        reviews: { nodes: reviews },
        reviewThreads: { nodes: reviewThreads },
    }
    process.stdout.write(`${JSON.stringify({ data: { repository: { pullRequest } } }, null, 2)}\n`)
} catch (error) {
    console.error((error.stderr || error.message).trim())
    process.exit(1)
}
