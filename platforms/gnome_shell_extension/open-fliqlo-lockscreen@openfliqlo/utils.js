const _timeoutIds = new Set();

/**
 * Promise that resolves after `ms` milliseconds.
 * Tracked so disable() can cancel pending sleeps.
 */
export function sleep(ms) {
    return new Promise(resolve => {
        const id = setTimeout(() => {
            _timeoutIds.delete(id);
            resolve();
        }, ms);
        _timeoutIds.add(id);
    });
}

/** Cancel all pending sleep() timers. Call from Extension.disable(). */
export function destroySleeps() {
    for (const id of _timeoutIds)
        clearTimeout(id);
    _timeoutIds.clear();
}
