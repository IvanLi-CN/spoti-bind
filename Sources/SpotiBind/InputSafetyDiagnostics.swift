import OSLog

enum InputSafetyDiagnostics {
    private static let logger = Logger(
        subsystem: "cc.ivanli.spotibind",
        category: "input-safety"
    )

    static func accessibilityTrustChanged(to trusted: Bool) {
        if trusted {
            logger.notice("Accessibility trust granted")
        } else {
            logger.error("Accessibility trust revoked")
        }
    }

    static func tapInstalled() {
        logger.notice("Media event tap installed")
    }

    static func tapRemoved() {
        logger.notice("Media event tap removed")
    }

    static func tapUnavailable() {
        logger.error("Media event tap could not be installed")
    }

    static func tapQuarantinedAfterTimeout() {
        logger.error("Media event tap quarantined after timeout")
    }

    static func tapQuarantinedAfterUserInput() {
        logger.error("Media event tap quarantined after system disable")
    }

    static func tapQuarantineReleased() {
        logger.notice("Media event tap quarantine released after trust restoration")
    }
}
