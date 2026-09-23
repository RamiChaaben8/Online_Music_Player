import { useState, useRef, useEffect } from "react"
import { createPortal } from "react-dom"
import { Monitor, Smartphone, Globe, Check, Loader } from "lucide-react"
import { useSyncStore, useRemotePlayback } from "../../hooks/useSyncSession"

export default function DevicePicker({ anchorRef, onClose }) {
  const allDevices   = useSyncStore((s) => s.allDevices)
  const activeDevice = useSyncStore((s) => s.activeDevice)
  const deviceId     = useSyncStore((s) => s.deviceId)
  const { claimHere } = useRemotePlayback()
  const [claiming, setClaiming] = useState(null)
  const [pos, setPos] = useState({ bottom: 90, right: 16 })
  const ref = useRef(null)

  // Calculate position from anchor button
  useEffect(() => {
    if (anchorRef?.current) {
      const rect = anchorRef.current.getBoundingClientRect()
      setPos({
        bottom: window.innerHeight - rect.top + 8,
        right:  window.innerWidth - rect.right,
      })
    }
  }, [anchorRef])

  // Close on outside click or Escape
  useEffect(() => {
    function onClick(e) {
      if (ref.current && !ref.current.contains(e.target) &&
          anchorRef?.current && !anchorRef.current.contains(e.target)) {
        onClose()
      }
    }
    function onKey(e) { if (e.key === "Escape") onClose() }
    document.addEventListener("mousedown", onClick)
    document.addEventListener("keydown", onKey)
    return () => {
      document.removeEventListener("mousedown", onClick)
      document.removeEventListener("keydown", onKey)
    }
  }, [onClose, anchorRef])

  const getIcon = (platform) => {
    if (platform === "android" || platform === "ios") return <Smartphone size={15} />
    if (platform === "windows" || platform === "macos") return <Monitor size={15} />
    return <Globe size={15} />
  }

  const handleClick = async (d) => {
    if (d.id === activeDevice?.id) return
    if (d.id !== deviceId) return
    setClaiming(d.id)
    try { await claimHere() }
    finally { setClaiming(null); onClose() }
  }

  const picker = (
    <div
      ref={ref}
      style={{
        position:        "fixed",
        bottom:          pos.bottom,
        right:           pos.right,
        backgroundColor: "#1c1c1c",
        border:          "1px solid #333",
        borderRadius:    12,
        padding:         "8px",
        boxShadow:       "0 8px 32px rgba(0,0,0,0.8)",
        zIndex:          9999,
        minWidth:        260,
        display:         "flex",
        flexDirection:   "column",
        gap:             2,
      }}
    >
      {/* Header */}
      <div style={{
        fontSize:      11,
        fontWeight:    700,
        letterSpacing: 1.2,
        color:         "#888",
        padding:       "4px 10px 8px",
        textTransform: "uppercase",
        borderBottom:  "1px solid #2a2a2a",
        marginBottom:  4,
      }}>
        Connect to a device
      </div>

      {allDevices.length === 0 && (
        <div style={{ fontSize: 13, color: "#999", padding: "12px 10px", textAlign: "center" }}>
          No devices found
        </div>
      )}

      {allDevices.map((d) => {
        const isActive   = d.id === activeDevice?.id
        const isThis     = d.id === deviceId
        const isClaiming = claiming === d.id
        const clickable  = isThis && !isActive

        return (
          <button
            key={d.id}
            onClick={() => handleClick(d)}
            disabled={!clickable || !!claiming}
            style={{
              display:         "flex",
              alignItems:      "center",
              gap:             12,
              padding:         "10px 10px",
              borderRadius:    8,
              backgroundColor: isActive ? "rgba(29,185,84,0.15)" : "transparent",
              color:           "#fff",
              border:          "none",
              cursor:          clickable && !claiming ? "pointer" : "default",
              textAlign:       "left",
              width:           "100%",
              transition:      "background 0.12s",
            }}
            onMouseEnter={(e) => {
              if (clickable && !claiming)
                e.currentTarget.style.backgroundColor = "#2a2a2a"
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = isActive
                ? "rgba(29,185,84,0.15)" : "transparent"
            }}
          >
            <div style={{
              width:           34,
              height:          34,
              borderRadius:    "50%",
              backgroundColor: isActive ? "#1DB954" : "#2d2d2d",
              display:         "flex",
              alignItems:      "center",
              justifyContent:  "center",
              flexShrink:      0,
              color:           isActive ? "#000" : "#ccc",
            }}>
              {isClaiming
                ? <Loader size={14} style={{ animation: "spin 1s linear infinite" }} />
                : getIcon(d.platform)
              }
            </div>

            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{
                fontSize:     13,
                fontWeight:   600,
                color:        isActive ? "#1DB954" : "#fff",
                overflow:     "hidden",
                textOverflow: "ellipsis",
                whiteSpace:   "nowrap",
              }}>
                {d.name}
                {isThis && (
                  <span style={{ color: "#666", fontWeight: 400, marginLeft: 4, fontSize: 12 }}>
                    (This device)
                  </span>
                )}
              </div>
              <div style={{ fontSize: 11, color: isActive ? "#1DB954" : "#777", marginTop: 2 }}>
                {isClaiming ? "Connecting…" : isActive ? "▶ Playing" : "Available"}
              </div>
            </div>

            {isActive && <Check size={16} color="#1DB954" style={{ flexShrink: 0 }} />}
          </button>
        )
      })}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  )

  return createPortal(picker, document.body)
}
