import { useState, useRef, useEffect } from "react"
import { Monitor, Smartphone, Globe, MonitorSpeaker } from "lucide-react"
import { useSyncStore } from "../../hooks/useSyncSession"
import { useAuthStore } from "../../stores/authStore"
import { useRemotePlayback } from "../../hooks/useSyncSession"

export default function DevicePicker({ anchorEl, onClose }) {
  const allDevices = useSyncStore((s) => s.allDevices)
  const activeDevice = useSyncStore((s) => s.activeDevice)
  const deviceId = useSyncStore((s) => s.deviceId)
  const { claimHere } = useRemotePlayback()

  const getIcon = (platform) => {
    if (platform === "android" || platform === "ios") return <Smartphone size={16} />
    if (platform === "windows" || platform === "macos") return <Monitor size={16} />
    if (platform === "web") return <Globe size={16} />
    return <MonitorSpeaker size={16} />
  }

  return (
    <div style={{
      position: "absolute",
      bottom: "60px",
      right: "0",
      background: "var(--color-card)",
      border: "1px solid var(--color-highlight-elevated)",
      borderRadius: 12,
      padding: 12,
      boxShadow: "0 4px 20px rgba(0,0,0,0.45)",
      zIndex: 500,
      width: 250,
      display: "flex",
      flexDirection: "column",
      gap: 8,
    }}>
      <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 4 }}>Connect to a device</div>
      {allDevices.map((d) => {
        const isActive = d.id === activeDevice?.id
        const isThis = d.id === deviceId
        return (
          <button
            key={d.id}
            onClick={() => {
              if (!isActive && isThis) claimHere()
              onClose()
            }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 12,
              padding: 8,
              borderRadius: 6,
              background: isActive ? "var(--color-highlight)" : "transparent",
              color: isActive ? "var(--color-button)" : "var(--color-text)",
              border: "none",
              cursor: (!isActive && isThis) ? "pointer" : "default",
              textAlign: "left",
            }}
          >
            {getIcon(d.platform)}
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 600 }}>{d.name} {isThis ? "(This browser)" : ""}</div>
              <div style={{ fontSize: 11, opacity: 0.7 }}>{isActive ? "Listening on" : "Available"}</div>
            </div>
          </button>
        )
      })}
    </div>
  )
}


