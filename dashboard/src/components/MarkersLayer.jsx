import React, { useEffect } from 'react';
import { useMap } from 'react-leaflet';
import L from 'leaflet';

export default function MarkersLayer({ materials, hazards, showMaterials, showHazards }) {
    const map = useMap();

    useEffect(() => {
        if (!map) return;
        const markers = [];

        // Custom Icons using divIcon for better styling without needing image assets
        const materialIcon = L.divIcon({
            className: 'custom-div-icon',
            html: `<div style="background-color:#22cc44;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,0.5);"></div>`,
            iconSize: [16, 16],
            iconAnchor: [8, 8]
        });

        const hazardIcon = L.divIcon({
            className: 'custom-div-icon',
            html: `<div style="background-color:#ffaa00;width:16px;height:16px;clip-path:polygon(50% 0%, 0% 100%, 100% 100%);border:1px solid #331111;box-shadow:0 0 4px rgba(0,0,0,0.5);"></div>`,
            iconSize: [16, 16],
            iconAnchor: [8, 16]
        });

        const severeHazardIcon = L.divIcon({
            className: 'custom-div-icon',
            html: `<div style="background-color:#ff2222;width:18px;height:18px;clip-path:polygon(50% 0%, 0% 100%, 100% 100%);border:2px solid white;box-shadow:0 0 6px rgba(255,0,0,0.8);"></div>`,
            iconSize: [20, 20],
            iconAnchor: [10, 20]
        });

        if (showMaterials && materials) {
            materials.forEach(m => {
                if (m.lat && m.lng) {
                    const text = m.data?.itemName || m.data?.description || '物資請求';
                    const marker = L.marker([m.lat, m.lng], { icon: materialIcon })
                        .bindPopup(`<b>📦 ${text}</b><br/>來源: ${m.origin.substring(0, 8)}`)
                        .addTo(map);
                    markers.push(marker);
                }
            });
        }

        if (showHazards && hazards) {
            hazards.forEach(h => {
                if (h.lat && h.lng) {
                    const text = h.data?.type || h.data?.description || '危險區域';
                    const icon = h.urgency >= 3 ? severeHazardIcon : hazardIcon;
                    const marker = L.marker([h.lat, h.lng], { icon: icon })
                        .bindPopup(`<b>⚠️ ${text}</b><br/>嚴重度: ${h.data?.severity || h.urgency}`)
                        .addTo(map);
                    markers.push(marker);

                    // Optionally add a circle representing the hazard radius if available
                    if (h.data?.radius) {
                        const circle = L.circle([h.lat, h.lng], {
                            radius: parseFloat(h.data.radius),
                            color: h.urgency >= 3 ? '#ff2222' : '#ffaa00',
                            fillOpacity: 0.2,
                            weight: 1
                        }).addTo(map);
                        markers.push(circle);
                    }
                }
            });
        }

        return () => {
            markers.forEach(m => map.removeLayer(m));
        };
    }, [map, materials, hazards, showMaterials, showHazards]);

    return null;
}
