import PhotosUI
import SwiftUI

/// Hoja «Editar slot» a pantalla completa (handoff `08`) con «¿Descartar los cambios?» (`09`).
struct EditSlotSheet: View {
    struct Request: Identifiable {
        let id = UUID()
        var slotId: UUID
        /// Abrir ya el selector de imagen («Cambiar a imagen» del menú).
        var pickImage = false
    }

    let request: Request
    /// «Borrar slot»: la pantalla principal sigue el flujo de borrar con deshacer.
    var onDelete: (UUID) -> Void = { _ in }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var original: SlotRecord?
    @State private var title = ""
    @State private var draft: ClipContent?
    @State private var text = ""
    @State private var libraryId = UUID()
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showDiscard = false
    @FocusState private var focus: Field?

    private enum Field { case title, content }

    private var isTextDraft: Bool {
        if case .text = draft { return true }
        return draft == nil
    }

    /// El contenido tal como quedaría guardado.
    private var effectiveContent: ClipContent? {
        guard isTextDraft else { return draft }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : .text(trimmed)
    }

    private var contentChanged: Bool { effectiveContent != original?.clipContent() }

    private var hasChanges: Bool {
        guard let original else { return false }
        return contentChanged
            || title.trimmingCharacters(in: .whitespacesAndNewlines) != original.title
            || libraryId != original.libraryId
    }

    private var libraryName: String {
        model.libraries.first { $0.id == libraryId }?.name ?? ""
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            titleField
            contentCard
            actions
            Button {
                dismiss()
                onDelete(request.slotId)
            } label: {
                Label("Vaciar slot", systemImage: "trash")
                    .font(SlotsFont.medium(16))
                    .foregroundStyle(SlotsColor.rosadoTexto)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(SlotsColor.rosado, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SlotsSpace.m)
        .padding(.top, 4)
        .padding(.bottom, SlotsSpace.s)
        .background(SlotsColor.papel.ignoresSafeArea())
        .overlay { if showDiscard { discardLayer } }
        .animation(.easeOut(duration: 0.2), value: showDiscard)
        .onAppear(perform: setUp)
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            Button {
                if hasChanges { focus = nil; showDiscard = true } else { dismiss() }
            } label: {
                Text("Cancelar")
                    .slotsText(15)
                    .foregroundStyle(SlotsColor.tinta)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(SlotsColor.botonSecundario, in: Capsule())
            }
            Spacer()
            Text(libraryName).slotsText(15).foregroundStyle(SlotsColor.textoSecundario).lineLimit(1)
            Spacer()
            Button(action: save) {
                Text("Guardar")
                    .slotsText(15)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(SlotsColor.tinta, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: SlotsSpace.s) {
            FieldLabel(text: "Título de la tarjeta")
            TextField("Título", text: $title)
                .font(SlotsFont.medium(32))
                .tracking(-0.035 * 32)
                .foregroundStyle(SlotsColor.tinta)
                .focused($focus, equals: .title)
                .submitLabel(.done)
            Rectangle()
                .fill(focus == .title ? SlotsColor.naranja : SlotsColor.linea)
                .frame(height: focus == .title ? 2 : 1)
        }
    }

    private var contentSummary: String {
        guard let content = effectiveContent else { return "Vacío" }
        switch content {
        case .text(let string):
            if SlotCardText.hexColor(string) != nil { return "Color" }
            let words = string.split { $0.isWhitespace || $0.isNewline }.count
            let kind = string.lowercased().hasPrefix("http") ? "Link" : "Texto"
            return "\(kind) · \(words == 1 ? "1 palabra" : "\(words) palabras")"
        case .image(let fileName):
            guard let size = SlotImageLoader.pixelSize(fileName: fileName) else { return "Imagen" }
            return "Imagen · \(Int(size.width)) × \(Int(size.height))"
        case .file:
            return "Archivo · \(content.fileDetail)"
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(contentSummary)
                Spacer()
                if isTextDraft { Text("Tocá para editar") }
            }
            .slotsText(12)
            .foregroundStyle(Color(slotsHex: 0x4A4744))

            if isTextDraft {
                TextEditor(text: $text)
                    .font(SlotsFont.regular(17))
                    .foregroundStyle(Color(slotsHex: 0x1A1A1A))
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .content)
                    .padding(.horizontal, -5)
            } else if case .image(let fileName) = draft {
                Group {
                    if let image = SlotImageLoader.thumbnail(fileName: fileName, maxPixel: 1400) {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let draft {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.fileName).slotsText(22, tracking: -0.02, lineHeight: 1.1).foregroundStyle(SlotsColor.tinta)
                    Text(draft.fileDetail).slotsText(15, medium: false).foregroundStyle(SlotsColor.textoSecundario)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(SlotsSpace.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [.white.opacity(0.85), Color(slotsHex: 0xE5E5E2, opacity: 0.7)],
                startPoint: .top, endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 1)
        }
    }

    private var actions: some View {
        HStack(spacing: SlotsSpace.s) {
            actionButton("Pegar\nportapapeles", icon: "doc.on.clipboard", action: pasteClipboard)
            actionButton("Cambiar\na imagen", icon: "photo") { showPhotos = true }
            Menu {
                ForEach(model.libraries) { library in
                    Button {
                        libraryId = library.id
                    } label: {
                        if library.id == libraryId {
                            Label(library.name, systemImage: "checkmark")
                        } else {
                            Text(library.name)
                        }
                    }
                }
            } label: {
                actionLabel("Mover de\nbiblioteca", icon: "arrow.right")
            }
        }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(title, icon: icon) }.buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        VStack(spacing: SlotsSpace.s) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium))
            Text(title).slotsText(13, lineHeight: 1.15).multilineTextAlignment(.center)
        }
        .foregroundStyle(SlotsColor.tinta)
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                .strokeBorder(.white.opacity(0.7), lineWidth: 1)
        }
    }

    /// Hoja chica «¿Descartar los cambios?» sobre la de edición.
    private var discardLayer: some View {
        ZStack(alignment: .bottom) {
            SlotsColor.tinta.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { showDiscard = false }
            VStack(spacing: SlotsSpace.m) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("¿Descartar los cambios?")
                        .slotsText(24, tracking: -0.02, lineHeight: 1.1)
                        .foregroundStyle(SlotsColor.tinta)
                    Text("Lo que cambiaste en este slot no se va a guardar.")
                        .slotsText(15, medium: false)
                        .foregroundStyle(SlotsColor.textoTerciario)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SlotsSpace.s)
                Button { dismiss() } label: {
                    Text("Descartar")
                        .slotsText(16)
                        .foregroundStyle(SlotsColor.rosadoTexto)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(SlotsColor.rosado, in: Capsule())
                }
                Button { showDiscard = false } label: {
                    Text("Seguir editando")
                        .slotsText(16)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(SlotsColor.tinta, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SlotsSpace.m)
            .padding(.top, SlotsSpace.l)
            .padding(.bottom, SlotsSpace.m)
            .background(SlotsColor.papel.opacity(0.96), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, SlotsSpace.s)
            .padding(.bottom, SlotsSpace.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .transition(.opacity)
    }

    // MARK: - Acciones

    private func setUp() {
        guard original == nil, let slot = model.store.slot(id: request.slotId) else { return }
        original = slot
        title = slot.title
        libraryId = slot.libraryId
        setDraft(slot.clipContent())
        if request.pickImage { showPhotos = true }
    }

    private func setDraft(_ content: ClipContent?) {
        draft = content
        if case .text(let string) = content { text = string } else { text = "" }
    }

    private func pasteClipboard() {
        guard let pasted = ClipboardReader.read() else { return }
        setDraft(pasted)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            if let saved = SlotFiles.saveImage(data: data, type: item.supportedContentTypes.first) {
                setDraft(saved)
            }
            photoItem = nil
        }
    }

    private func save() {
        model.applyEdit(
            slotId: request.slotId,
            title: title,
            content: effectiveContent,
            contentChanged: contentChanged,
            libraryId: libraryId
        )
        dismiss()
    }
}
