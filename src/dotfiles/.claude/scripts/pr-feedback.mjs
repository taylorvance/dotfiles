#!/usr/bin/env node
import { execFileSync } from 'node:child_process'

function sh(cmd, args) {
    return execFileSync(cmd, args, { encoding: 'utf8' })
}

function currentRepo() {
    const { owner, name } = JSON.parse(sh('gh', ['repo', 'view', '--json', 'owner,name']))
    return { owner: owner.login, repo: name }
}

function currentPrNumber() {
    return JSON.parse(sh('gh', ['pr', 'view', '--json', 'number'])).number
}

const QUERY = `query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$number){comments(first:100){nodes{author{login}body createdAt}}reviews(first:100){nodes{author{login}state body submittedAt comments(first:100){nodes{author{login}body path line createdAt}}}}reviewThreads(first:100){nodes{isResolved isOutdated comments(first:100){nodes{author{login}body path line createdAt}}}}}}}`

try {
    const [prArg] = process.argv.slice(2)
    const prNumber = prArg ? Number(prArg) : currentPrNumber()
    const { owner, repo } = currentRepo()

    const out = sh('gh', [
        'api',
        'graphql',
        '-f',
        `query=${QUERY}`,
        '-f',
        `owner=${owner}`,
        '-f',
        `repo=${repo}`,
        '-F',
        `number=${prNumber}`,
    ])

    process.stdout.write(out)
} catch (err) {
    console.error((err.stderr || err.message).trim())
    process.exit(1)
}
