"""IST timezone utility for all timestamp conversions."""

from datetime import datetime, timezone, timedelta

# IST is UTC+5:30
IST = timezone(timedelta(hours=5, minutes=30))


def now_ist() -> datetime:
    """Get current time in IST."""
    return datetime.now(IST)


def to_ist(dt: datetime | None) -> str | None:
    """Convert a datetime to IST ISO string."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        # Assume UTC if naive
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(IST).isoformat()


def to_ist_display(dt: datetime | None) -> str | None:
    """Convert to IST human-readable format: '27 Mar 2026, 2:30 PM IST'."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    ist_dt = dt.astimezone(IST)
    return ist_dt.strftime("%d %b %Y, %I:%M %p IST")
