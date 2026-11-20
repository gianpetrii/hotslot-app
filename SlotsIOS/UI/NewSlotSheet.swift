import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Hoja «Nuevo slot» (handoff `10` y `11`).
struct NewSlotSheet: View {
    struct Request: Identifiable {
        let id = UUID()
        /// Slot vacío que se va a llenar; `nil` usa el primer vacío de la biblioteca o agrega uno.
        var slotId: UUID?
        /// Abrir ya con lo que hay en el portapapeles («Guardar como slot»).
        var useClipboard = false
        /// Desde la card «Nuevo slot»: siempre agrega uno al final, sin llenar un hueco.
        var atEnd = false
    }

    enum Kind: String, CaseIterable, Identifiable {
        case text = "Texto", link = "Link", image = "Imagen", file = "Archivo"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .text: return "text.alignleft"
            case .link: return "link"
            case .image: return "photo"
            case .file: return "doc"
            }
        }
    }

    let request: Request
    /// Avisa el id del slot guardado y su biblioteca.
    var onSaved: (UUID, UUID) -> Void = { _, _ in }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Kind = .text
    @State private var text = ""
    /// Imagen o archivo elegido.
    @State private var attachment: ClipContent?
    @State private var name = ""
    @State private var nameEdited = false
    @State private var libraryId = UUID()
    @State private var clipboardAvailable = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showNewLibrary = false
    @FocusState private var focus: Field?

    private enum Field { case content, name }

    private var content: ClipContent? {
        switch kind {
        case .text:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : .text(trimmed)
        case .link:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .text(trimmed.lowercased().hasPrefix("http") ? trimmed : "https://\(trimmed)")
        case .image:
            if case .image = attachment { return attachment }
            return nil
        case .file:
            if case .file = attachment { return attachment }
            return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SheetHeader(title: "Nuevo slot") { dismiss() }

                if clipboardAvailable, content == nil {
                    ClipboardCard(actionTitle: "Usar", action: useClipboard)
                }

                contentField

                VStack(spacing: SlotsSpace.s) {
                    FieldLabel(text: "Tipo")
                    HStack(spacing: SlotsSpace.s) {
                        ForEach(Kind.allCases) { option in kindButton(option) }
                    }
                }

                VStack(spacing: SlotsSpace.s) {
                    FieldLabel(text: "Nombre de la tarjeta")
                    SheetTextField(placeholder: suggestedName, text: $name, isFocused: focus == .name)
                        .focused($focus, equals: .name)
                        .onChange(of: name) { _, _ in if focus == .name { nameEdited = true } }
                }

                VStack(spacing: SlotsSpace.s) {
                    FieldLabel(text: "Biblioteca")
                    LibraryPicker(libraries: model.libraries, selection: $libraryId) { showNewLibrary = true }
                }

                SheetPrimaryButton(title: "Guardar slot", action: save)
                    .disabled(content == nil)
                    .padding(.top, SlotsSpace.s)
            }
            .padding(.horizontal, SlotsSpace.m)
            .padding(.top, 28)
            .padding(.bottom, SlotsSpace.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .onAppear(perform: setUp)
        .photosPicker(isPresented: $showPhotos, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in loadPhoto(item) }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: kind == .image ? [.image] : [.item]) { result in
            guard case .success(let url) = result else { return }
            importFile(url)
        }
        .sheet(isPresented: $showNewLibrary) {
            NewLibrarySheet { libraryId = $0 }
        }
        .slotsSheetStyle()
    }

    // MARK: - Contenido

    @ViewBuilder private var contentField: some View {
        switch kind {
        case .text:
            TextField("Escribí o pegá el texto", text: $text, axis: .vertical)
                .font(SlotsFont.regular(17))
                .foregroundStyle(SlotsColor.tinta)
                .lineLimit(3...8)
                .focused($focus, equals: .content)
                .padding(SlotsSpace.m)
                .background(.white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        case .link:
            SheetTextField(placeholder: "https://", text: $text, isFocused: focus == .content, keyboard: .URL)
                .focused($focus, equals: .content)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .image:
            if case .image(let fileName) = attachment {
                imagePreview(fileName)
            } else {
                HStack(spacing: SlotsSpace.s) {
                    pickButton("Elegir de Fotos", icon: "photo.on.rectangle") { showPhotos = true }
                    pickButton("Archivos", icon: "folder") { showFiles = true }
                }
            }
        case .file:
            if case .file = attachment, let attachment {
                HStack(spacing: SlotsSpace.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.fileName).slotsText(15).foregroundStyle(SlotsColor.tinta).lineLimit(1)
                        Text(attachment.fileDetail).slotsText(13, medium: false).foregroundStyle(SlotsColor.textoSecundario)
                    }
                    Spacer()
                    changeButton { showFiles = true }
                }
                .padding(SlotsSpace.m)
                .background(.white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
            } else {
                pickButton("Elegir archivo", icon: "folder") { showFiles = true }
            }
        }
    }

    private func imagePreview(_ fileName: String) -> some View {
        ZStack {
            SlotsColor.naranja
            if let image = SlotImageLoader.thumbnail(fileName: fileName, maxPixel: 1200) {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Elegir de Fotos", systemImage: "photo.on.rectangle") { showPhotos = true }
                Button("Archivos", systemImage: "folder") { showFiles = true }
            } label: {
                changeLabel.background(.white.opacity(0.85), in: Capsule())
            }
            .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            if let size = SlotImageLoader.pixelSize(fileName: fileName) {
                Text("Imagen · \(Int(size.width)) × \(Int(size.height))")
                    .slotsText(13)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .padding(12)
            }
        }
    }

    private var changeLabel: some View {
        Text("Cambiar")
            .slotsText(13)
            .foregroundStyle(SlotsColor.tinta)
            .padding(.horizontal, 14)
            .frame(height: 34)
    }

    private func changeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) { changeLabel.background(SlotsColor.botonSecundario, in: Capsule()) }
            .buttonStyle(.plain)
    }

    private func pickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SlotsSpace.s) {
                Image(systemName: icon).font(.system(size: 15, weight: .medium))
                Text(title).slotsText(15)
            }
            .foregroundStyle(SlotsColor.tinta)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .overlay {
                RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous)
                    .strokeBorder(SlotsColor.bordePunteado, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func kindButton(_ option: Kind) -> some View {
        let isSelected = option == kind
        return Button {
            kind = option
            if option == .text || option == .link { focus = .content }
        } label: {
            VStack(spacing: SlotsSpace.s) {
                Image(systemName: option.icon).font(.system(size: 16, weight: .medium))
                Text(option.rawValue).slotsText(13)
            }
            .foregroundStyle(isSelected ? .white : SlotsColor.tinta)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isSelected ? SlotsColor.naranja : .white, in: RoundedRectangle(cornerRadius: SlotsRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Acciones

    /// Nombre sugerido según el contenido: el dominio de un link, el nombre del archivo, etc.
    private var suggestedName: String {
        guard let content else { return "" }
        switch content {
        case .text(let string):
            if kind == .link, let host = URL(string: string)?.host {
                return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
            if let hex = SlotCardText.hexColor(string) { return hex }
            let words = string.split(whereSeparator: \.isWhitespace)
            let name = words.prefix(4).joined(separator: " ")
            return words.count > 4 || name.count > 28 ? String(name.prefix(28)).trimmingCharacters(in: .whitespaces) + "…" : name
        case .image: return "Imagen"
        case .file: return content.fileName
        }
    }

    private func setUp() {
        libraryId = request.slotId.flatMap { model.store.slot(id: $0)?.libraryId } ?? model.activeLibraryId
        clipboardAvailable = ClipboardReader.hasContent
        if request.useClipboard { useClipboard() }
    }

    /// Acá sí se lee el portapapeles: lo pidió la persona. El tipo se detecta solo.
    private func useClipboard() {
        guard let pasted = ClipboardReader.read() else {
            clipboardAvailable = false
            return
        }
        switch pasted {
        case .text(let string):
            let isLink = string.lowercased().hasPrefix("http") && !string.contains(where: \.isWhitespace)
            kind = isLink ? .link : .text
            text = string
        case .image:
            kind = .image
            attachment = pasted
        case .file:
            kind = .file
            attachment = pasted
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let type = item.supportedContentTypes.first
            if let saved = SlotFiles.saveImage(data: data, type: type) {
                kind = .image
                attachment = saved
            }
            photoItem = nil
        }
    }

    private func importFile(_ url: URL) {
        if kind == .image {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            attachment = SlotFiles.saveImage(data: data, type: UTType(filenameExtension: url.pathExtension))
        } else {
            attachment = SlotFiles.importFile(from: url)
        }
    }

    private func save() {
        guard let content else { return }
        let title = nameEdited && !name.trimmingCharacters(in: .whitespaces).isEmpty ? name : (name.isEmpty ? suggestedName : name)
        guard let id = model.saveNewSlot(content: content, title: title, libraryId: libraryId, intoSlotId: request.slotId, atEnd: request.atEnd) else { return }
        onSaved(id, libraryId)
        dismiss()
    }
}
