# Fix the application identity before first release

Superseded by [Rename the pre-release application identity to SpotiBind](0007-rename-the-pre-release-application-identity-to-spotibind.md).

The app used `cc.ivanli.fastpotifykeys` as its planned bundle identifier. Accessibility authorization, preferences, and login-item registration are associated with this identity, so changing it after distribution would require people to grant access and configure the app again.
