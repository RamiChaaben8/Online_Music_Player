import { useState, useRef, useEffect } from "react"
import { Monitor, Smartphone, Globe, MonitorSpeaker, Check } from "lucide-react"
import { useSyncStore, useRemotePlayback } from "../../hooks/useSyncSession"

export default function DevicePicker({ onClose }) {
  const allDevices   = useSyncStore((s) => s.allDevices)
  const activeDevice = useSyncStore((s) => s.activeDevice)
  const deviceId     = useSyncStore((s) => s.deviceId)
  const { claimHere } = useRemotePlayback()
  const [claiming, setClaiming] = useState(null) // deviceId being claimed
  const ref = useRef(null)

  // Close on outside click
  useEffect(() => {
    function handler(e) {
      if (ref.current && !ref.current.contains(e.target)) onClose()
    }
    document.addEventListener("mousedown", handler)
    return () => document.removeEventListener("mousedown", handler)
  }, [onClose])

  const getIcon = (platform) => {
    if (platform === "android" || platform === "ios") return <Smartphone size={16} />
    if (platform === "windows" || platform === "macos") return <Monitor size={16} />
    return <Globe size={16} />
  }

  const handleClick = async (d) => {
    // If already active, nothing to do
    if (d.id === activeDevice?.id) return
    // Only we can claim ourselves — we can't remote-claim another device
    if (d.id !== deviceId) return
    setClaiming(d.id)
    try {
      await claimHere()
    } finally {
      setClaiming(null)
      onClose()
    }
  }

  return (
    <div
      ref={ref}
      style={{
        position:   "absolute",
        bottom:     "calc(100% + 8px)",
        right:      0,
        background: "var(--color-card)",
        border:     "1px solid var(--color-highlight-elevated)",
        borderRadius: 12,
        padding:    "12px 8px",
        boxShadow:  "0 4px 20px rgba(0,0,0,0.55)",
        zIndex:     500,
        minWidth:   240,
        display:    "flex",
        flexDirection: "column",
        gap:        4,
      }}
    >
      <div style={{
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: 1,
        color: "var(--color-subtext)",
        padding: "0 10px 6px",
        textTransform: "uppercase",
      }}>
        Connect to a device
      </div>

      {allDevices.length === 0 && (
        <div style={{ fontSize: 13, color: "var(--color-subtext)", padding: "8px 10px" }}>
          No devices found
        </div>
      )}

      {allDevices.map((d) => {
        const isActive  = d.id === activeDevice?.id
        const isThis    = d.id === deviceId
        const isClaiming = claiming === d.id
        // Can only click this device (to claim it back)
        const clickable = isThis && !isActive

        return (
          <button
            key={d.id}
            onClick={() => handleClick(d)}
            disabled={!clickable || !!claiming}
            style={{
              display:    "flex",
              alignItems: "center",
              gap:        12,
              padding:    "9px 10px",
              borderRadius: 8,
              background: isActive ? "color-mix(in srgb, var(--color-button) 12%, transparent)" : "transparent",
              color:      isActive ? "var(--color-button)" : "var(--color-text)",
              border:     "none",
              cursor:     clickable && !claiming ? "pointer" : "default",
              textAlign:  "left",
              width:      "100%",
              transition: "background 0.12s",
            }}
            onMouseEnter={(e) => {
              if (clickable && !claiming) e.currentTarget.style.background = "var(--color-highlight)"
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = isActive
                ? "color-mix(in srgb, var(--color-button) 12%, transparent)"
                : "transparent"
            }}
          >
            {/* Icon */}
            <div style={{
              width: 32, height: 32, borderRadius: "50%",
              background: isActive ? "var(--color-button)" : "var(--color-highlight)",
              display: "flex", alignItems: "center", justifyContent: "center",
              flexShrink: 0,
              color: isActive ? "#000" : "var(--color-text)",
            }}>
              {getIcon(d.platform)}
            </div>

            {/* Labels */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontSize: 13, fontWeight: 600,
                overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
              }}>
                {d.name}{isThis ? " (This device)" : ""}
              </div>
              <div style={{ fontSize: 11, color: isActive ? "var(--color-button)" : "var(--color-subtext)", marginTop: 1 }}>
                {isClaiming ? "Connecting…" : isActive ? "Playing" : "Available"}
              </div>
            </div>

            {/* Active checkmark */}
            {isActive && <Check size={16} color="var(--color-button)" style={{ flexShrink: 0 }} />}
          </button>
        )
      })}
    </div>
  )
}
