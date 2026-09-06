# Rename the pre-release application identity to SpotiBind

## Status

Accepted

## Decision

Before the first public release, the project uses `SpotiBind` as its package,
executable, bundle, artifact, and public documentation identity. Its macOS
bundle identifier is `cc.ivanli.spotibind`.

The existing `fastpotify` CLI integration remains unchanged. SpotiBind is an
independent project and is not affiliated with or endorsed by Spotify.

## Consequences

The pre-release `cc.ivanli.fastpotifykeys` identity is not a compatibility
contract. Once SpotiBind has been distributed, its bundle identifier must stay
stable because macOS associates Accessibility authorization, preferences, and
login-item registration with that identity.
