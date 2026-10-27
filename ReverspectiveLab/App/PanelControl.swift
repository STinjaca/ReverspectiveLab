//  PanelControl.swift — ReverspectiveLab
//  El panel lateral con los controles de la demo: qué se ve, cómo se
//  invierte, dónde está el visor y los datos de la inversión.

import SwiftUI

struct PanelControl: View {
    /// `@Bindable` deja sacar bindings (`$estado.modo`) de una clase
    /// `@Observable`, para conectarla a pickers y sliders.
    @Bindable var estado: EstadoVisor

    var body: some View {
        Form {
            Section("Vista") {
                Picker("Vista", selection: $estado.modo) {
                    Text("Escena original").tag(ModoVista.escena)
                    Text("Pieza invertida").tag(ModoVista.pieza)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Inversión") {
                Picker("Estrategia", selection: $estado.parametros.estrategia) {
                    Text(Estrategia.global.rawValue).tag(Estrategia.global)
                    Text(Estrategia.porObjeto.rawValue).tag(Estrategia.porObjeto)
                }
                LabeledContent("s = \(estado.parametros.s, format: .number.precision(.fractionLength(2)))") {
                    Slider(value: $estado.parametros.s, in: 0...1)
                }
            }

            Section("Cámara") {
                HStack {
                    Button("Ir a C") { estado.irAC() }
                    Button("Reiniciar órbita") { estado.reiniciarOrbita() }
                }
                LabeledContent("θ") {
                    Text(estado.theta.map { "\($0, format: .number.precision(.fractionLength(1)))°" } ?? "—")
                        .monospacedDigit()
                }
            }

            Section("Datos") {
                pivotes
                LabeledContent("Recortados") {
                    Text("\(estado.porcentajeRecortados, format: .number.precision(.fractionLength(1))) %")
                        .monospacedDigit()
                }
                autoprueba
            }
        }
        .formStyle(.grouped)
    }

    /// Los pivotes que usa la estrategia elegida: D en la global; un d_b por
    /// objeto en la de por objeto.
    @ViewBuilder private var pivotes: some View {
        if let pivotes = estado.pivotes {
            switch estado.parametros.estrategia {
            case .global:
                LabeledContent("Pivote D") { distancia(pivotes.global) }
            case .porObjeto, .hibrida:
                ForEach(pivotes.porObjeto.keys.sorted(), id: \.self) { id in
                    LabeledContent("Pivote \(estado.nombresObjetos[id] ?? "ID \(id)")") {
                        distancia(pivotes.porObjeto[id]!)
                    }
                }
            }
        }
    }

    private func distancia(_ d: Float) -> some View {
        Text(d, format: .number.precision(.fractionLength(3))).monospacedDigit()
    }

    /// Un renglón por chequeo; al pasar el cursor se ve el valor medido.
    @ViewBuilder private var autoprueba: some View {
        if estado.autoprueba.isEmpty {
            LabeledContent("Autoprueba", value: "solo en Debug")
        } else {
            let pasaron = estado.autoprueba.filter(\.paso).count
            LabeledContent("Autoprueba",
                           value: "\(pasaron == estado.autoprueba.count ? "✓" : "✗") \(pasaron)/\(estado.autoprueba.count)")
            ForEach(estado.autoprueba, id: \.nombre) { chequeo in
                Text("\(chequeo.paso ? "✓" : "✗") \(chequeo.nombre)")
                    .font(.caption)
                    .foregroundStyle(chequeo.paso ? Color.secondary : Color.red)
                    .help(chequeo.detalle)
            }
        }
    }
}
