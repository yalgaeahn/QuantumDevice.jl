"""Semantic source export for the pilot qiskit-metal transmon migration."""

QMETAL_SOURCE_SPEC = {
    "design_name": "qmetal_single_transmon",
    "chip": {
        "size_um": [4010.0, 3710.0],
        "simulation_box_um": [4000.0, 3700.0],
        "substrate_material": "sapphire",
    },
    "layers": {
        "metal": "device metallization",
        "gap": "etched ground cutout",
        "ports": "lumped readout ports",
        "junction": "lumped Josephson element",
    },
    "cpw": {
        "trace_um": 10.0,
        "gap_um": 6.0,
        "bridge_spacing_um": 300.0,
        "readout_length_um": 2700.0,
    },
    "transmon": {
        "cap_width_um": 24.0,
        "cap_length_um": 620.0,
        "cap_gap_um": 30.0,
        "junction_gap_um": 12.0,
        "island_rounding_um": 0.0,
    },
    "readout": {
        "claw_gap_um": 6.0,
        "claw_width_um": 34.0,
        "claw_length_um": 121.0,
        "coupling_gap_um": 5.0,
        "coupling_length_um": 400.0,
        "hanger_length_um": 500.0,
        "bend_radius_um": 50.0,
        "meander_turns": 5,
        "total_length_um": 5000.0,
        "shield_width_um": 2.0,
    },
    "junction": {
        "inductance_h": 1.4860e-8,
        "capacitance_f": 5.5e-15,
        "direction": "+Y",
    },
    "ports": {
        "port_1": {"direction": "+X", "impedance_ohm": 50.0},
        "port_2": {"direction": "+X", "impedance_ohm": 50.0},
    },
    "solver": {
        "order_default": 1,
        "modes": 2,
        "target_ghz": 2.5,
        "amr_max_iterations": 0,
    },
}
