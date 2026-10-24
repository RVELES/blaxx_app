//
//  BXCampos.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Campos do tema (02-inventario §2.7): rótulo mono 11 MAIÚSC cinza acima; superfície, borda 1 linha,
//  raio 12, padding 13/14, 48 pt, 16/500 (16 evita zoom). Foco: borda tinta + halo neon 35 % de 3 pt.
//  Erro: borda e texto perigoTexto. Cada tipo define teclado, preenchimento automático, caixa e máscara.
//  Nenhum campo guarda valor fora do `Binding` (senha nunca é persistida).
//

import SwiftUI

struct BXCampo: View {
    enum Tipo {
        case texto, nome, email, emailOuCPF, cpf, celular, senha, novaSenha, pontos, dinheiro
        case mensagem(limite: Int)

        var ehSenha: Bool {
            switch self { case .senha, .novaSenha: return true; default: return false }
        }
        var limite: Int? {
            if case .mensagem(let l) = self { return l }
            return nil
        }
    }

    let rotulo: String
    @Binding var texto: String
    let tipo: Tipo
    let placeholder: String
    let dica: String?
    let erro: String?

    @FocusState private var focado: Bool
    @State private var mostrarSenha = false

    init(_ rotulo: String, texto: Binding<String>, tipo: Tipo = .texto, placeholder: String = "",
         dica: String? = nil, erro: String? = nil) {
        self.rotulo = rotulo
        self._texto = texto
        self.tipo = tipo
        self.placeholder = placeholder
        self.dica = dica
        self.erro = erro
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(BXCor.cinza.opacity(0.75))
    }

    @ViewBuilder private var entrada: some View {
        if tipo.ehSenha {
            HStack(spacing: 10) {
                Group {
                    if mostrarSenha {
                        TextField(rotulo, text: $texto, prompt: prompt)
                    } else {
                        SecureField(rotulo, text: $texto, prompt: prompt)
                    }
                }
                .focused($focado)
                Button(mostrarSenha ? "Ocultar" : "Mostrar") { mostrarSenha.toggle() }
                    .bxFonte(.rotulo)
                    .foregroundStyle(BXCor.tinta)
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 32)
            }
        } else if let limite = tipo.limite {
            TextField(rotulo, text: $texto, prompt: prompt, axis: .vertical)
                .lineLimit(3...6)
                .focused($focado)
                .overlay(alignment: .bottomTrailing) {
                    Text("\(texto.count)/\(limite)")
                        .font(BXFonte.fonte(.recibo, tamanho: 11))
                        .foregroundStyle(texto.count >= limite ? BXCor.perigoTexto : BXCor.cinza)
                        .offset(y: 4)
                }
        } else {
            TextField(rotulo, text: $texto, prompt: prompt)
                .focused($focado)
        }
    }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            Text(rotulo).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .accessibilityHidden(true)
            entrada
                .bxFonte(.campo)
                .foregroundStyle(BXCor.tinta)
                .tint(BXCor.tinta)
                .modifier(BXConfigTeclado(tipo: tipo))
                .padding(.vertical, 13)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(BXCor.superficie, in: forma)
                .overlay(forma.strokeBorder(erro != nil ? BXCor.perigoTexto : (focado ? BXCor.tinta : BXCor.linha), lineWidth: 1))
                .background {
                    RoundedRectangle(cornerRadius: BXRaio.sm + 3, style: .continuous)
                        .fill(BXCor.halo)
                        .padding(-3)
                        .opacity(focado ? 1 : 0)
                }
                .animation(BXMovimento.ease, value: focado)
                .contentShape(forma)
                .onTapGesture { focado = true }
                .accessibilityLabel(rotulo)
                .accessibilityHint(erro ?? dica ?? "")
            if let erro {
                Text(erro).bxFonte(.legenda).foregroundStyle(BXCor.perigoTexto)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let dica {
                Text(dica).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(.error, trigger: erro) { antes, depois in antes == nil && depois != nil }
        .onChange(of: texto) { _, novo in
            let m = mascarar(novo)
            if m != novo { texto = m }
        }
        .onAppear {
            let m = mascarar(texto)
            if m != texto { texto = m }
        }
    }

    private func mascarar(_ s: String) -> String {
        switch tipo {
        case .cpf: return BXFormato.mascaraCPF(s)
        case .celular: return BXFormato.mascaraCelular(s)
        case .pontos: return BXFormato.mascaraPontos(s)
        case .dinheiro: return BXFormato.mascaraDinheiro(s)
        case .emailOuCPF:
            let semPontuacao = s.filter { $0 != "." && $0 != "-" }
            if !semPontuacao.isEmpty, semPontuacao.allSatisfy(\.isNumber) { return BXFormato.mascaraCPF(semPontuacao) }
            return s
        case .mensagem(let limite): return String(s.prefix(limite))
        default: return s
        }
    }
}

/// Teclado, preenchimento automático e caixa por tipo de campo (só iOS).
private struct BXConfigTeclado: ViewModifier {
    let tipo: BXCampo.Tipo

    func body(content: Content) -> some View {
        #if os(iOS)
        switch tipo {
        case .texto:
            content.textInputAutocapitalization(.sentences)
        case .nome:
            content.textContentType(.name).textInputAutocapitalization(.words).submitLabel(.next)
        case .email:
            content.textContentType(.emailAddress).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.next)
        case .emailOuCPF:
            content.textContentType(.username).keyboardType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.next)
        case .cpf:
            content.keyboardType(.numberPad).autocorrectionDisabled()
        case .celular:
            content.textContentType(.telephoneNumber).keyboardType(.phonePad)
        case .senha:
            content.textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
        case .novaSenha:
            content.textContentType(.newPassword).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .pontos, .dinheiro:
            content.keyboardType(.numberPad)
        case .mensagem:
            content.textInputAutocapitalization(.sentences)
        }
        #else
        content
        #endif
    }
}

// MARK: - Busca

/// Campo de busca grande (56 pt, 18/600, fundo superficie2) com a lupa em quadrado neon 40 dentro.
struct BXCampoBusca: View {
    @Binding var texto: String
    let placeholder: String
    @FocusState private var focado: Bool

    init(texto: Binding<String>, placeholder: String) {
        self._texto = texto
        self.placeholder = placeholder
    }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous)
        HStack(spacing: 10) {
            BXIcone(.busca, tamanho: .cartao)
            TextField(placeholder, text: $texto, prompt: Text(placeholder).foregroundStyle(BXCor.cinza))
                .bxFonte(.campoBusca)
                .foregroundStyle(BXCor.tinta)
                .tint(BXCor.tinta)
                .focused($focado)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !texto.isEmpty {
                Button { texto = "" } label: {
                    BXGlifo(.fechar, cor: BXCor.cinza, lado: 14)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .frame(minHeight: 56)
        .background(BXCor.superficie2, in: forma)
        .overlay(forma.strokeBorder(focado ? BXCor.tinta : BXCor.linha, lineWidth: 1))
        .background {
            RoundedRectangle(cornerRadius: BXRaio.sm + 3, style: .continuous)
                .fill(BXCor.halo).padding(-3).opacity(focado ? 1 : 0)
        }
        .contentShape(forma)
        .onTapGesture { focado = true }
        .animation(BXMovimento.ease, value: focado)
    }
}

// MARK: - Código de verificação

/// Código de N dígitos em caixas separadas; aceita colar o código inteiro e o preenchimento do SMS.
struct BXCampoCodigo: View {
    @Binding var codigo: String
    let digitos: Int
    @FocusState private var focado: Bool

    init(codigo: Binding<String>, digitos: Int = 6) {
        self._codigo = codigo
        self.digitos = digitos
    }

    var body: some View {
        let chars = Array(codigo)
        ZStack {
            TextField("", text: $codigo)
                .focused($focado)
                #if os(iOS)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                #endif
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .accessibilityLabel("Código de verificação")
            HStack(spacing: 8) {
                ForEach(0..<digitos, id: \.self) { i in
                    let atual = focado && (i == min(chars.count, digitos - 1))
                    let forma = RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous)
                    Text(i < chars.count ? String(chars[i]) : "")
                        .font(BXFonte.fonte(.saldoMono, tamanho: 22))
                        .foregroundStyle(BXCor.tinta)
                        .frame(maxWidth: 52, minHeight: 56)
                        .frame(maxWidth: .infinity)
                        .background(BXCor.superficie, in: forma)
                        .overlay(forma.strokeBorder(atual ? BXCor.tinta : BXCor.linha, lineWidth: atual ? 1.5 : 1))
                        .background {
                            RoundedRectangle(cornerRadius: BXRaio.sm + 3, style: .continuous)
                                .fill(BXCor.halo).padding(-3).opacity(atual ? 1 : 0)
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focado = true }
            .accessibilityHidden(true)
        }
        .onChange(of: codigo) { _, novo in
            let d = String(novo.filter(\.isNumber).prefix(digitos))
            if d != novo { codigo = d }
        }
    }
}

// MARK: - Interruptor

/// Interruptor 46 × 26: desligado trilho linha, ligado neon; botão branco de 20 com sombra leve.
struct BXInterruptorEstilo: ToggleStyle {
    init() {}
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(BXMovimento.ease) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? BXCor.neon : BXCor.linha)
                    Circle().fill(Color.white)
                        .frame(width: 20, height: 20)
                        .padding(3)
                        .bxSombra(.leve)
                }
                .frame(width: 46, height: 26)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
