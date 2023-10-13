import type { SourceType } from "./definitions"

export type validObjectValue = Record<string, any> | null | undefined

const shallowEqualObjects = function (
  objA: validObjectValue,
  objB: validObjectValue
): boolean {
  if (objA === objB) {
    return true
  }

  if (!objA || !objB) {
    return false
  }

  const aKeys = Object.keys(objA)
  const bKeys = Object.keys(objB)
  const len = aKeys.length

  if (bKeys.length !== len) {
    return false
  }

  for (let i: number = 0; i < len; i++) {
    const key = aKeys[i]!

    if (
      objA[key] !== objB[key] ||
      !Object.prototype.hasOwnProperty.call(objB, key)
    ) {
      return false
    }
  }

  return true
}

const sourceEqualityFn = (prevSource: SourceType, nextSource: SourceType) => {
  if (!prevSource || !nextSource) {
    return false
  }

  return (
    prevSource.url === nextSource.url &&
    shallowEqualObjects(prevSource.headers, nextSource.headers)
  )
}

export default sourceEqualityFn