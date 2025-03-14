	%include 'util.inc'
	%include 'io.inc'
	%include 'strings.inc'
	
	global main
	
	section .text
	; windows api functions
	extern _FindFirstFileA@8
	extern _FindNextFileA@8
	extern _GetLastError@0
	extern _SetLastError@4
	extern _CreateDirectoryA@8
GetRootDir: ; get root dir from esi
	pusha
	
	mov eax, esi
	mov ecx, 0
	.untilFirstDot:
		mov bl, [eax + ecx]
		cmp bl, 0
		je .error
		cmp bl, '.'
		je .untilSlash
		inc ecx
		jmp .untilFirstDot
	.untilSlash:
		mov bl, [eax + ecx]
		cmp ecx, 0
		je .error
		cmp bl, '/'
		je .copy
		cmp bl, '\'
		je .copy
		dec ecx
		jmp .untilSlash
	.copy:
		mov edi, ecx
		inc edi
		mov [rootDir + edi], byte 0; null terminate the string
		mov edi, 0
		.copyLoop:
			mov bl, [eax + edi]
			mov [rootDir + edi], bl
			inc edi
			cmp edi, ecx
			jl .copyLoop 
	.done:
		mov esi, rootDir
		inc esi
		mov edi, rootDir
		call StrCpy
		popa
		clc
		ret
	.error:
		popa
		stc
		ret
ReadCommandLineArgs:
		push eax
		push ebx
		push esi
		
		call getargs
		
		mov esi, eax
		call GetRootDir
		
	.untilExtension:              ; read until the first . character
		lodsb
		cmp al, 0                    ; null byte
		je .err
		cmp al, '.'                  ; . character
		jne .untilExtension
		
	.untilArgs:                   ; read until the first space character
		lodsb
		cmp al, 0                    ; null byte
		je .err
		cmp al, ' '                  ; space character
		jne .untilArgs
		
		mov ebx, path
	.getPath:                     ; store the path in the path variable
		lodsb
		cmp al, 0                    ; null byte
		je .err
		cmp al, ' '                  ; space character
		je .pathDone
		mov [ebx], al
		inc ebx
		jmp .getPath
	.pathDone:
		mov [ebx], byte 0            ; null terminate the path
		mov ebx, mode
		
		lodsb
		cmp al, 0                    ; null byte
		je .err
		cmp al, 'i'                  ; i character (in)
		je .setMode
		cmp al, 'o'                  ; o character (out)
		je .setMode
		jmp .err                     ; invalid mode
	.setMode:
		mov [ebx], al                ; store the mode in the mode variable
		lodsb
		cmp al, 0                    ; null byte
		jne .err                     ; if there are more characters, it's an error
	.done:
		pop esi
		pop ebx
		pop eax
		
		ret
	.err:
		pop esi
		pop ebx
		pop eax
		
		stc                          ; set the carry flag to indicate an error
		
		ret
OpenFile: ; 
	push eax
	push ebx

	mov eax, openPath
	mov ebx, [openFileMode]
	call fio_open
	cmp eax, 0                   ; if eax is 0, there was an error
	je .error
	mov [openFileHandle], eax
	jmp .done
	.error:
		pop ebx
		pop eax
		
		stc                          ; set the carry flag to indicate an error
		ret
	.done:
		pop ebx
		pop eax
		
		clc
		ret
CloseFile:
	push eax
	push ebx
	
	mov eax, [closeFileHandle]
	call fio_close
	mov [closeFileHandle], dword 0
	
	pop ebx
	pop eax
	
	ret

GetType:                      ; get the type, directory or file
	push eax
	push esi
	
	mov esi, path
	.getType:
		lodsb
		cmp al, 0
		je .dir
		cmp al, '.'
		je .file
		jmp .getType
	.dir:
		mov eax, type
		mov byte [eax], 'd'
		jmp .done
	.file:
		mov eax, type
		mov byte [eax], 'f'
		jmp .done
	.done:
		pop esi
		pop eax
		
		ret
	
InitCounts: ; initialize the counts array -> byte: byteValue, dword: count (0)
	push eax
	push ebx
	push ecx
	
	mov eax, 256
	mov ecx, 0
	.init:
		mov [counts + ecx * 5], cl ; byte
		mov [counts + ecx * 5 + 1], dword 0 ; count
		inc ecx
		cmp ecx, eax
		jne .init
		
	pop ecx
	pop ebx
	pop eax
	
	ret
	
GetCounts: ; read the file and count the bytes
	push eax
	push ebx
	push ecx
	push esi
	push edi
	
	; mov esi, path
	; mov edi, openPath
	; call StrCpy ; copy the path to the openPath variable
	; mov [openFileMode], dword 0 ; read mode
	; call OpenFile
	; jc .error
	; mov eax, [openFileHandle]
	; mov [readFileHandle], eax

	mov eax, [readFileHandle]
	mov ecx, 1                   ; read 1 byte at a time
	mov ebx, byteRead
	.read:
		call fio_read
		cmp edx, 1                   ; if edx is 1, end of file
		jne .done
		push ecx
		xor ecx, ecx
		mov cl, byte [byteRead]      ; move the byte read into cl
		mov esi, [counts + ecx * 5 + 1] ; get the count for the byte
		inc esi                      ; increment the count
		mov [counts + ecx * 5 + 1], esi ; store the count
		pop ecx
		jmp .read
	.done:
		pop edi
		pop esi
		pop ecx
		pop ebx
		pop eax
		
		clc
		ret
	.error:
		stc                          ; set the carry flag to indicate an error
		
		pop edi
		pop esi
		pop ecx
		pop ebx
		pop eax

		ret
SortCounts: ; sort the counts in ascending order
	pusha

	mov ecx, 1 ; i
	.for1: ; for i = 1 to 254
		mov al, byte [counts + ecx * 5] ; get the byte, a[i].byte
		mov edi, [counts + ecx * 5 + 1] ; get the count, a[i].count
		mov esi, ecx ; j
		inc esi ; j = i + 1
		.for2: ; for j = i + 1 to 255
			mov dl, byte [counts + esi * 5] ; get the byte, a[j].byte
			mov ebx, [counts + esi * 5 + 1] ; get the count, a[j].count
			cmp edi, ebx ; if a[i].count > a[j].count
			jng .next
			.swap: ; swap a[i] and a[j]
				mov [counts + ecx * 5], dl ; a[i].byte = a[j].byte
				mov [counts + esi * 5], al ; a[j].byte = a[i].byte
				mov [counts + ecx * 5 + 1], ebx ; a[i].count = a[j].count
				mov [counts + esi * 5 + 1], edi ; a[j].count = a[i].count
				mov al, dl ; a[i].byte = a[j].byte
				mov edi, ebx ; a[i].count = a[j].count
				dec esi ; j--
			.next:
			inc esi ; j++
			cmp esi, 255 ; if j > 256
			jle .for2
		inc ecx ; i++
		cmp ecx, 254 ; if i > 255
		jle .for1
	popa

	ret
WriteFileName: ; write file name and initialize variables
	push eax
	push ebx
	push ecx
	push esi
	push edi
	
	mov ecx, 0
	.skipNulls:
		mov esi, [counts + ecx * 5 + 1] ; get the count
		cmp esi, 0 ; if the count is 0
		jne .write
		cmp ecx, 256
		jg .done
		inc ecx
		jmp .skipNulls
	.write:
		mov [firstNotNullIndex], ecx	

		mov eax, [writeFileHandle]
		mov esi, 255
		sub esi, ecx ; esi = 255 - ecx
		inc esi ; esi = 255 - ecx + 1
		mov [numLeafs], esi ; store the number of non-zero counts
		mov [numInternalNodes], esi ; store the number of internal nodes
		dec dword [numInternalNodes] ; numInternalNodes = numLeafs - 1
		mov esi, ecx
		
		; write the type of the file
		mov ebx, type
		mov ecx, 1 ; write 1 byte
		call fio_write ; write the type
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error
		
		; !!!!!! DEBUG !!!!!!
		mov ebx, path ; KEEP THIS LINE
		; mov ebx, debugOutPath ; REMOVE THIS LINE
		.writeFileName:
			cmp [ebx], byte 0 ; if the byte is 0, it's the end of the string
			je .doneWriteFileName
			call fio_write ; write the byte
			cmp edx, 1 ; if edx is not 1, there was an error
			jne .error
			inc ebx ; move to the next byte in the string
			jmp .writeFileName
		.doneWriteFileName:
		call fio_write ; write the 0 byte

		mov ebx, numLeafs
		mov ecx, 4 ; write 1 bytes
		call fio_write ; write the number of bytes to the file
		cmp edx, 4 ; if edx is not 1, there was an error
		jne .error

	;  kiveve kiirja a countokat
	; 	.writeData:
	; 		cmp esi, 256
	; 		je .doneWrite

	; 		lea ebx, [counts + esi * 5] ; get the address of the byte
	; 		mov ecx, 1 ; write 1 byte
	; 		call fio_write ; write the byte
	; 		cmp edx, 1 ; if edx is not 1, there was an error
	; 		jne .errorWrite
			
	; 		lea ebx, [counts + esi * 5 + 1] ; get the address of the count
	; 		mov ecx, 4 ; write 4 bytes
	; 		call fio_write ; write the count
	; 		cmp edx, 4 ; if edx is not 4, there was an error
	; 		jne .errorWrite

	; 		inc esi
	; 		jmp .writeData
	; .doneWrite:
	; 	jmp .done
	.done:
		pop edi
		pop esi
		pop ecx
		pop ebx
		pop eax
		
		clc
		ret
	.error:
		stc                          ; set the carry flag to indicate an error
		
		pop edi
		pop esi
		pop ecx
		pop ebx
		pop eax
		
		ret
SetOutFilePath: ; set the output file path
	push esi
	push edi
	push ecx
	push eax


	mov esi, path
	mov edi, outPath
	call StrCpy ; copy the path to the outPath variable
	mov ecx, 0
	.untilExtension:
		mov al, [esi + ecx]
		cmp al, 0
		je .error ; if there is no extension, it's an error
		cmp al, '.'
		je .extension
		inc ecx
		jmp .untilExtension
	.extension:
		inc ecx
		mov al, 'b'
		mov [edi + ecx], al
		inc ecx
		mov al, 'i'
		mov [edi + ecx], al
		inc ecx
		mov al, 'n'
		mov [edi + ecx], al
		inc ecx
		mov al, 0
		mov [edi + ecx], al
		jmp .done
	.error:
		pop eax
		pop ecx
		pop edi
		pop esi
		
		stc ; set the carry flag to indicate an error
		ret
	.done:
		pop eax
		pop ecx
		pop edi
		pop esi
		
		clc ; clear the carry flag to indicate no error
		ret
InitTree:
	push eax
	push ebx
	push ecx
	push edx

	mov eax, [tree] ; tree -> pointer ( eax = address of the root node )
	mov ecx, 0
	.init:
		mov edx, ecx
		imul edx, 17 ; calculate the offset
		lea ebx, [eax + edx] ; get the address of the node
		mov [ebx], byte 0 ; byte
		mov [ebx + 1], dword 0 ; count
		mov [ebx + 5], dword 0 ; left
		mov [ebx + 9], dword 0 ; right
		mov [ebx + 13], dword 0 ; parent
		inc ecx
		cmp ecx, [numNodes]
		jne .init

	; initialize freeNode pointer
	mov eax, [tree]
	add eax, 17 ; skip the root node
	mov ecx, [numLeafs]
	imul ecx, 17 ;
	add eax, ecx ; eax = address of the first free node
	mov [freeNode], eax ; store the pointer in the freeNode variable
	
	pop edx
	pop ecx
	pop ebx
	pop eax
	
	ret 
FindNodes: ; uses node1 and node2 variables to store pointers to nodes
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi

	; initialize node1 and node2
	mov [node1], dword 0 ; node1 = 0
	mov [node2], dword 0 ; node2 = 0

	mov eax,  [tree] ; tree -> pointer
	add eax, 17 ; skip the root node
	mov ecx, 0 ; index of the node
	mov edi, 0x7FFFFFFF ; min = 2^31 - 1
	.findNode1:
		mov esi, ecx
		imul esi, 17 ; calculate the offset
		lea ebx, [eax + esi] ; get the address of the node
		cmp [ebx], byte 0 ; skip free nodes
		je .next
		mov edx, [ebx + 13] ; get the parent
		cmp edx, 0 ; if the parent is 0, it's a not found node
		jne .next
		mov edx, [ebx + 1] ; get the count
		cmp edx, edi ; if the count is less than the min
		jge .next
		mov edi, edx ; min = count
		mov [node1], ebx ; node1 = node
		mov [node1Index], ecx ; node1Index = index
		.next:
			inc ecx
			cmp ecx, [numSearchNodes]
			jl .findNode1
	cmp edi, 0x7FFFFFFF ; if edi == 2^31 - 1, there was an error
	je .error
	.foundNode1:
	cmp [node1], dword 0 ; if node1 is 0, there was an error
	je .error

	mov ecx, 0 ; index of the node
	mov edi, 0x7FFFFFFF ; min = 2^31 - 1
	.findNode2:
		mov esi, ecx
		imul esi, 17 ; calculate the offset
		lea ebx, [eax + esi] ; get the address of the node
		cmp [ebx], byte 0 ; skip free nodes
		je .next2
		cmp ebx, [node1] ; if ebx == node1
		je .next2
		mov edx, [ebx + 13] ; get the parent
		cmp edx, 0 ; if the parent is 0, it's a not found node
		jne .next2
		mov edx, [ebx + 1] ; get the count
		cmp edx, edi ; if the count is less than the min
		jge .next2
		mov edi, edx ; min = count
		mov [node2], ebx ; node2 = node
		mov [node2Index], ecx ; node2Index = index
		.next2:
			inc ecx
			cmp ecx, [numSearchNodes]
			jl .findNode2
	cmp edi, 0x7FFFFFFF ; if ebx == 2^31 - 1, there was an error
	je .error
	.foundNode2:
	cmp [node1], dword 0 ; if node1 is 0, there was an error
	je .error
	cmp [node2], dword 0 ; if node2 is 0, there was an error
	je .error

	; check node1.count < node2.count
	mov eax, [node1]
	mov ebx, [node2]
	mov ecx, [eax + 1] ; get the count of node1
	mov edx, [ebx + 1] ; get the count of node2
	cmp ecx, edx ; if node1.count <= node2.count
	jle .done
	; swap node1 and node2
	mov eax, [node1]
	mov ebx, [node2]
	mov [node1], ebx
	mov [node2], eax
	.done:
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax

		clc ; clear the carry flag to indicate no error
		ret
	.error:
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax

		stc ; set the carry flag to indicate an error
		ret

AllocTree:
	push eax
	push ecx

	mov eax, [numLeafs] ; number of leaf nodes = n
	imul eax, 2
	sub eax, 1 ; numNodes = 2*n - 1
	mov [numNodes], eax ; store the number of nodes in the numNodes variable
	mov ecx, eax
	dec ecx ; ecx = numNodes - 1
	mov [numSearchNodes], ecx ; store the number of search nodes in the numSearchNodes variable
	imul eax, 17 ; number of bytes to allocate
	call mem_alloc ; allocate memory for the tree, pointer in eax
	cmp eax, 0 ; if eax is 0, there was an error
	je .error
	mov [tree], eax ; store the pointer in the tree variable

	pop ecx
	pop eax
	clc
	ret
	.error:
		pop ecx
		pop eax
		stc ; set the carry flag to indicate an error
		ret
HuffmanTree: ; create the huffman tree
; huffmann tree node structure: byte 1, count 4 , right pointer 4, left pointer 4 , parent point 4 = 17 bytes per node
; huffman tree structure: root node, leaf nodes, internal nodes
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi
	
	mov eax, [tree] 
	add eax, 17 ; get the address of the first leaf node
	mov ecx, [numLeafs] ; number of nodes per level
	mov edi, counts ; get the address of the counts array
	mov esi, [firstNotNullIndex] ; index of the counts array
	imul esi, 5 ; calculate the offset
	add edi, esi ; get the address of the first non-null count
	mov esi, 0 ; index of the counts array
	.initLeafs:
		mov bl, [edi] ; get the byte
		mov [eax], bl ; store the byte
		mov ebx, [edi + 1] ; get the count
		mov [eax + 1], ebx ; store the count
		inc esi
		add eax, 17 ; move to the next leaf node
		add edi, 5 ; move to the next count
		cmp esi, ecx
		jl .initLeafs
	
	mov ecx, [numInternalNodes] ; number of internal nodes
	dec ecx ; ecx = numInternalNodes - 1 the root node is set manually
	cmp ecx, 0 ; if there are no internal nodes
	je .setRoot
	.buildTree:
		call FindNodes
		jc .error

		;debug
		mov eax, [node1]
		mov ebx, [node2]

		; create the parent node (internal node)
		mov eax, [freeNode] ; get the address of the first free node
		mov [eax], byte 'i' ; set the byte of the internal node to 'i'
		mov ebx, [node1] ; get the address of node1
		mov [ebx + 13], eax ; set the parent of node1 to the address of the parent node
		mov [eax + 5], ebx ; set the left pointer of the parent node to node1
		mov edx, [ebx + 1] ; get the count of node1
		mov [eax + 1], edx ; set the count of the parent node to the count of node1

		mov ebx, [node2] ; get the address of node2
		mov [ebx + 13], eax ; set the parent of node2 to the address of the parent node
		mov [eax + 9], ebx ; set the right pointer of the parent node to node2
		mov edx, [ebx + 1] ; get the count of node2
		add [eax + 1], edx ; add the count of node2 to the count of the parent node
	
		; update the freeNode pointer
		add eax, 17 ; move to the next free node
		mov [freeNode], eax ; store the address of the next free node
		dec ecx ; edx--
		cmp ecx, 0 ; if ecx == 0
		je .setRoot
		jmp .buildTree
	.setRoot:
		call FindNodes ; result in node1 and node2
		jc .error
	.createRoot:
		; create the parent node
		mov eax, [tree] ; get the address of the root node
		
		push ebx
		mov bl, [delimiter]
		mov [eax], bl ; set the byte of the root node to delimiter
		pop ebx
		mov ebx, [node1] ; get the address of node1
		mov [ebx + 13], eax ; set the parent of node1 to the address of the parent node
		mov [eax + 5], ebx ; set the left pointer of the parent node to node1
		mov edx, [ebx + 1] ; get the count of node1
		mov [eax + 1], edx ; set the count of the parent node to the count of node1

		mov ebx, [node2] ; get the address of node2
		mov [ebx + 13], eax ; set the parent of node2 to the address of the parent node
		mov [eax + 9], ebx ; set the right pointer of the parent node to node2
		mov edx, [ebx + 1] ; get the count of node2
		add [eax + 1], edx ; add the count of node2 to the count of the parent node
		jmp .done
	.done :
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax
		
		clc ; clear the carry flag to indicate no error
		ret
	.error:
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax
		
		stc ; set the carry flag to indicate an error
		ret

AllocCodes: ; (1 byte + 4 bytes) * 257
	push eax
	push ebx
	push ecx

	mov eax, [numLeafs] ; number of leaf nodes = n
	imul eax, 257 ; number of bytes to allocate
	call mem_alloc ; allocate memory for the codes, pointer in eax
	cmp eax, 0 ; if eax is 0, there was an error
	je .error
	mov [codes], eax ; store the pointer in the codes variable

	pop ecx
	pop ebx
	pop eax
	clc
	ret
	.error:
		pop ecx
		pop ebx
		pop eax
		stc ; set the carry flag to indicate an error
		ret
InitCodes:
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi

	mov eax, [codes]
	mov ecx, [numLeafs]
	imul ecx, 257
	mov esi, 0 ; index of the codes array
	.init:
		mov [eax + esi], byte 0 ; byte
		inc esi
		cmp esi, ecx
		jl .init
	.done:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	clc
	ret
GetCodes: ; go through the tree and find the code for each leaf
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi

	mov eax, [tree] ; get the address of the root node
	add eax, 17 ; skip the root node
	mov ecx, 0 ; index of the tree
	mov edi, 0 ; index for the codes array
	.forEachLeaf:		
		push edi
		push ecx
		mov ecx, [codes]
		imul edi, 257 ; calculate the offset
		lea esi, [ecx + edi] ; get the address of the codes array
		pop ecx
		pop edi

		lea ebx, [eax] ; get the address of the leaf node
		push ebx
		mov bl, [ebx] ; get the byte
		mov [esi], bl ; store the byte in the codes array
		pop ebx
		inc esi ; move to the next byte in the codes array
		.whileUp:
			push eax
			mov al, [delimiter]
			cmp [ebx], al ; if the byte is delimiter, it's the root node
			pop eax
			je .whileDown
			push ebx ; save the address of the node
			mov ebx, [ebx + 13] ; get the parent
			jmp .whileUp
		.whileDown:
			cmp [ebx + 5], dword 0 ; if the left pointer is 0, it's a leaf node
			je .nextLeaf
			pop eax ; child node address
			push eax
			cmp [ebx + 5], eax ; if the left pointer is the child node address
			je .left ; if the left pointer is the child node address
			mov al, '1' ; right
			mov [esi], al ; store the byte in the codes array
			inc esi ; move to the next byte in the codes array
			jmp .next
			.left:
				mov al, '0' ; left
				mov [esi], al ; store the byte in the codes array
				inc esi ; move to the next byte in the codes array
			.next:
			pop eax ; get the address of the child node
			mov ebx, eax ; set the address of the child node as the current node
			jmp .whileDown ; keep going down the tree
		.nextLeaf:
			add eax, 17 ; move to the next leaf node
			inc ecx ; move to the next node in the tree
			inc edi ; move to the next byte in the codes array
			cmp ecx, [numLeafs] ; if ecx == numLeafs
			jl .forEachLeaf
		

	.done:
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	clc
	ret
	.error:
		pop edi
		pop esi
		pop edx
		pop ecx
		pop ebx
		pop eax
		stc ; set the carry flag to indicate an error
		ret
FindCode: ; find the code of byteRead
push eax
push ebx
push ecx
push esi

mov eax, [codes]
mov ecx, 0
.find:
	mov esi, ecx
	imul esi, 257 ; calculate the offset
	lea ebx, [eax + esi] ; get the byte's address
	mov bl, [ebx] ; get the byte
	cmp bl, byte [byteRead] ; if the byte is byteRead
	je .found
	inc ecx
	cmp ecx, [numLeafs] ; if ecx == numLeafs
	jl .find
	jmp .error
.found:
	mov esi, ecx
	imul esi, 257 ; calculate the offset
	lea ebx, [eax + esi] ; get the byte's address
	inc ebx ; move to the code
	mov [byteCodePtr1], ebx ; store the address of the code
	jmp .done
.error:
	pop esi
	pop ecx
	pop ebx
	pop eax
	stc ; set the carry flag to indicate an error
	ret
.done:
	pop esi
	pop ecx
	pop ebx
	pop eax
	clc ; clear the carry flag to indicate no error
	ret
WriteCode: ; edi = codeString
pusha
mov eax, [writeFileHandle]
push eax ; save openFileHandle
mov eax, 0
mov ebx, 0
mov edi, codeString
mov ecx, 0
.convertString:
	cmp ecx, 8 ; if ecx == 8, it's the end of the string
	je .done
	mov bl, [edi + ecx] ; get the byte
	cmp bl, 0
	je .nullByte
	sub bl, '0' ; convert the byte to a number
	shl eax, 1 ; shift eax left by 1
	add al, bl ; add the byte to eax
	inc ecx
	jmp .convertString
	.nullByte:
		shl eax, 1 ; shift eax left by 1
		inc ecx
		jmp .convertString
.done:
	mov [codeStringByte], al 
	pop eax ; restore openFileHandle
	mov ebx, codeStringByte
	mov ecx, 1 ; write 1 byte
	call fio_write ; write the byte
	cmp edx, 1 ; if edx is not 1, there was an error
	jne .error
	popa
	inc dword [numBytesWritten]
	clc ; clear the carry flag to indicate no error
	ret
.error:
	popa
	stc ; set the carry flag to indicate an error
	ret
WriteEncodedFile: ; write the encoded file contents
	pusha
	mov eax, [readFileHandle]
	mov ebx, 0
	mov ecx, 0
	call fio_seek
	cmp edx, 0
	jne .error

	mov ecx, 1
	mov ebx, byteRead
	mov edi, codeString
	mov [codeStringLen], dword 0
	mov [codeString + 8], byte 0 ; terminate the string
	.forEachByteRead:
		mov eax, [readFileHandle]
		call fio_read
		cmp edx, 1
		jne .done

		call FindCode
		jc .error
		mov esi, [byteCodePtr1]
		.whileCodeNotFull:
			cmp [esi], byte 0 ; if the byte is 0, it's the end of the code
			je .doneCode
			push eax
			mov al, [esi] ; a code byte
			mov [edi], al ; store the code byte
			pop eax
			inc byte [codeStringLen]
			inc esi ; move to the next byte in the code
			inc edi ; move to the next byte in the codeString
			cmp [codeStringLen], byte 8
			je .writeCode
			jmp .whileCodeNotFull
		.writeCode:
			mov edi, codeString
			call WriteCode
			jc .error
			mov [codeStringLen], byte 0
			; reset the code string
			mov [codeString + 0], byte 0
			mov [codeString + 1], byte 0
			mov [codeString + 2], byte 0
			mov [codeString + 3], byte 0
			mov [codeString + 4], byte 0
			mov [codeString + 5], byte 0
			mov [codeString + 6], byte 0
			mov [codeString + 7], byte 0
			jmp .whileCodeNotFull
		.doneCode:
			jmp .forEachByteRead
	.done:
		cmp [codeStringLen], byte 0 ; if codeStringLen == 0, there is no code to write
		je .exit
		push eax
		mov esi, codeString
		call StrLen
		mov [usefulBits], eax ; number of useful bits in the codeStringByte
		mov edi, codeString
		pop eax
		call WriteCode
		jc .error
	.exit:
		popa
		clc
		ret
	.error:
		popa
		stc
		ret
FreeTree: ; free the memory allocated for the tree
	push eax
	mov eax, [tree]
	call mem_free
	mov [tree], dword 0
	pop eax
	clc
	ret
FreeCodes: ; free the memory allocated for the codes
	push eax
	mov eax, [codes]
	call mem_free
	mov [codes], dword 0
	pop eax
	clc
	ret
WriteCodes: ; write the codes
pusha
	mov eax, [writeFileHandle]

	mov edi, 0 ; index
	mov esi, 0 ; offset
	.write:
		cmp edi, [numLeafs] ; if edi == numLeafs
		je .done
		mov esi, edi
		imul esi, 257 ; calculate the offset
		push edi
		mov edi, [codes]
		lea ebx, [edi + esi] ; get the address of the code
		pop edi
		mov ecx, 1 ; write 1 byte
		call fio_write ; write the byte
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error
		inc ebx ; move to the code itself
		.writeCode:
			xor edx, edx
			mov dl, [ebx] ; get the byte
			mov [byteRead], dl ; store the byte
			mov ecx, 1 ; write 1 byte
			push ebx
			mov ebx, byteRead
			call fio_write ; write the byte
			pop ebx
			cmp edx, 1 ; if edx is not 1, there was an error
			jne .error
			cmp [ebx], byte 0 ; if the byte is 0, it's the end of the code
			je .doneWriteCode
			inc ebx ; move to the next byte in the code
			jmp .writeCode
		.doneWriteCode:
		inc edi ; move to the next code
		jmp .write
.done:
	popa
	clc
	ret
.error:
	popa
	stc
	ret
ZipFile:
	call InitCounts

	call GetCounts
	jc .error

	call SortCounts
	call WriteFileName ; not just the file name

	call AllocTree
	jc .error

	call InitTree

	call HuffmanTree
	jc .error

	call AllocCodes
	jc .error
	call InitCodes
	call GetCodes
	call WriteCodes
	jc .error

	mov [numBytesWritten], dword 0

	mov eax, [writeFileHandle]
	mov ebx, dwordRead
	mov [ebx], dword 0
	mov ecx, 4
	call fio_write
	cmp edx, 4
	jne .error

	mov eax, [writeFileHandle]
	mov ebx, byteRead
	mov [ebx], byte 0
	mov ecx, 1
	call fio_write
	cmp edx, 1
	jne .error

	call WriteEncodedFile
	jc .error

	mov eax, [writeFileHandle]
	mov ebx, 1 ; current position
	mov ecx, [numBytesWritten]
	imul ecx, -1
	sub ecx, 5
	call fio_seek
	cmp edx, 0
	; jne .error

	mov eax, [writeFileHandle]
	mov ebx, numBytesWritten
	mov ecx, 4 ; write 4 bytes
	call fio_write ; write the number of bytes written
	cmp edx, 4
	; jne .error

	mov ebx, usefulBits
	mov ecx, 1
	call fio_write ; write the number of useful bits
	cmp edx, 1 ; if edx is not 1, there was an error
	; jne .error

	mov eax, [writeFileHandle]
	mov ebx, 1 ; current position
	mov ecx, [numBytesWritten]
	call fio_seek
	cmp edx, 0
	; jne .error

	call FreeTree
	call FreeCodes
	jmp .done
	.error:
		stc	; set the carry flag to indicate an error
		ret
	.done:
		clc
		ret
CleanCounts:
	push eax
	push ecx
	mov eax, counts
	mov ecx, [numLeafs]
	.loop:
		mov [eax], byte 0
		mov [eax + 1], dword 0
		add eax, 5
		loop .loop
	pop ecx
	pop eax
	clc
	ret
ReadCodes: ; read the codes
	pusha
	mov eax, [readFileHandle]
	mov edi, 0 ; index
	mov esi, 0 ; offset
	.read:
		cmp edi, [numLeafs] ; if edi == numLeafs
		je .done
		mov ebx, byteRead
		mov ecx, 1 ; read 1 byte
		call fio_read ; read the byte
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error
		mov esi, edi
		imul esi, 257 ; calculate the offset
		push edi
		mov edi, [codes]
		lea ebx, [edi + esi]
		pop edi
		mov dl, [byteRead] ; get the byte
		mov [ebx], dl ; store the byte
		inc ebx ; move to the code itself
		.readCode:
			push ebx
			mov ebx, byteRead
			mov ecx, 1 ; read 1 byte
			call fio_read ; read the byte
			pop ebx
			cmp edx, 1 ; if edx is not 1, there was an error
			jne .error
			mov dl, [byteRead] ; get the byte
			mov [ebx], dl ; store the byte
			cmp [ebx], byte 0 ; if the byte is 0, it's the end of the code	
			je .doneReadCode
			inc ebx ; move to the next byte in the code
			jmp .readCode
		.doneReadCode:
		inc edi ; move to the next code
		jmp .read
.done:	
	popa
	clc ; clear the carry flag to indicate no error
	ret
.error:
	popa
	stc ; set the carry flag to indicate an error
	ret
ConvertToString: ; convert the byteRead to a string, stored in codeString
pusha
	mov eax, 0
	mov al, [byteRead]
	mov edi, codeString ; address of the string
	mov ecx, 8 ; number of bits
	mov edx, 0x80 ; mask
	.convert:
		cmp ecx, 0 ; if ecx == 0, it's the end of the string
		je .done
		push eax
		and eax, edx ; mask the byte
		push ecx
		dec ecx
		shr eax, cl
		pop ecx
		add eax, '0' ; convert the byte to a character
		mov [edi], al ; store the byte
		pop eax
		inc edi ; move to the next byte in the string
		dec ecx ; move to the next bit
		shr edx, 1 ; move the mask to the right
		jmp .convert
.done:
	inc edi ; move to the next byte in the string
	mov [edi], byte 0 ; terminate the string
	popa
	clc
	ret
StrEquals: ; compare the strings at esi and edi, return 1 if equal, 0 otherwise in eax
push ebx
push esi
push edi
	mov eax, esi
	mov ebx, edi
	.while:
		push eax
		push ebx
		mov al, [eax]
		mov bl, [ebx]
		cmp al, bl
		jne .notEqual
		cmp al, 0
		je .equal
		pop ebx
		pop eax

		inc eax
		inc ebx
		jmp .while
	.equal:
		mov eax, 1
		jmp .done
	.notEqual:
		mov eax, 0
	.done:
		pop ebx
		pop ebx

		pop edi
		pop esi
		pop ebx
		clc
		ret

Decode: ; decode the decodeCode string if possible
pusha
	; concatenate the codeString to decodeCode
	mov esi, codeString
	mov edi, decodeCode
	call StrCat

	mov ecx, 1 ; zero byte position
	.beforeForZeroPos:
		xor edx, edx
		mov esi, decodeCode ; get the address of the decodeCode string
		.forZeroPos:
			mov dl, [esi + ecx] ; store the byte where the zero will be
			mov [esi + ecx], byte 0 ; set the byte to 0
			mov eax, 0 ; index of the codes array
			.forEachCode:
				push esi
				push eax
				mov esi, eax
				mov eax, [codes] ; get the address of the codes array
				imul esi, 257 ; calculate the offset
				lea ebx, [eax + esi] ; get the address of the code
				inc ebx ; move to the code
				pop eax
				pop esi

				; compare the strings
				push eax
				mov edi, ebx
				mov esi, decodeCode
				call StrEquals
				cmp eax, 1 ; if eax == 1, the strings are equal
				pop eax
				je .found
				; next code
				inc eax
				cmp eax, [numLeafs] ; if eax == numLeafs
				jl .forEachCode
				jmp .nextZeroPos
				.found:
					push eax
					push ebx
					push ecx
					push edx
					mov al, [ebx - 1] ; get the byte
					mov [byteRead], al ; store the byte
					mov eax, [writeFileHandle]
					mov ebx, byteRead
					mov ecx, 1 ; write 1 byte
					call fio_write ; write the byte
					cmp edx, 1 ; if edx is not 1, there was an error
					pop edx
					pop ecx
					pop ebx
					pop eax
					jne .error
					; copy the rest of the string to the beginning
					mov [esi + ecx], dl ; restore the byte
					lea ebx, [esi + ecx] ; get the address of the byte
					mov esi, ebx ; set the address of the byte as the current address
					mov edi, decodeCode ; get the address of the decodeCode string
					call StrCpy

					cmp byte [decodeCode], byte 0 ; if the first byte is 0, it's the end of the string
					je .done

					mov ecx, 1 ; zero byte position
					mov eax, 0 ; index of the codes array
					jmp .beforeForZeroPos

			.nextZeroPos:
			mov [esi + ecx], dl ; restore the byte
			inc ecx ; move to the next byte
			push eax
			mov esi, decodeCode
			call StrLen
			inc eax
			cmp ecx, eax ; if ecx == eax, it's the end of the string
			pop eax
			je .done
			jmp .beforeForZeroPos
.done:
	popa
	clc
	ret
.error:
	popa
	stc
	ret
WriteDecodedFile: ; 
pusha
	mov edi, [numBytesWritten] ; number of bytes to read
	.readFileContent:
		mov eax, [readFileHandle]
		mov ebx, byteRead
		mov ecx, 1 ; read 1 byte
		call fio_read ; read the byte
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error

		cmp edi, 1 ; if edi == 1 it's the last byte
		je .last 
		dec edi

		.decode:
			call ConvertToString
			call Decode
			jmp .readFileContent
		.last:
			call ConvertToString	
			mov eax, [usefulBits]
			mov [codeString + eax], byte 0 ; terminate the string
			call Decode
			mov esi, decodeCode
			call StrLen	
			cmp eax, 0 ; if eax == 0, there is no code to write
.done:
	popa
	clc
	ret
.error:
	popa
	stc
	ret
UnzipFileRec: ; unzip a file, recursive for directories
	pusha

	mov eax, [readFileHandle]
	; get the type
	mov ecx, 1	; read 1 byte at a time
	mov ebx, byteRead
	call fio_read
	cmp edx, 1	; if edx is 1, end of file
	jne .done
	mov bl, [byteRead]	; move the byte read into bl
	mov [type], bl
	cmp bl, 'd'
	je .dir
	cmp bl, 'f'
	je .file
	jmp .error
	.file:
		mov esi, outPath
		mov ebx, byteRead
		.cpyFileName:
			call fio_read
			
			push eax
			mov al, [byteRead]
			mov [esi], al
			pop eax

			inc esi ; move to the next byte in the string
			cmp byte [byteRead], byte 0
			jne .cpyFileName

		; get the number of bytes
		mov ecx, 4 ; read 4 bytes
		mov ebx, dwordRead
		call fio_read
		cmp edx, 4
		jne .error
		mov ebx, [ebx] ; get the number of bytes
		mov [numLeafs], ebx ; store the number of bytes in the numLeafs variable
		
		call AllocCodes
		jc .error
		call InitCodes
		call ReadCodes

		mov eax, [readFileHandle]
		mov ebx, numBytesWritten
		mov ecx, 4 ; read 4 bytes
		call fio_read
		cmp edx, 4
		jne .error

		; read usefulBits
		mov eax, [readFileHandle]
		mov ebx, usefulBits
		mov ecx, 1 ; read 1 byte
		call fio_read
		cmp edx, 1
		jne .error


		; open the output file
		mov esi, outPath
		mov edi, openPath
		call StrCpy ; copy the path to the openPath variable
		mov [openFileMode], dword 1 ; write mode
		push eax
		call OpenFile
		pop eax
		jc .error
		mov esi, [openFileHandle]
		mov [writeFileHandle], esi

		call WriteDecodedFile
		jc .error
		
		; close the write file
		mov eax, [writeFileHandle]
		mov [closeFileHandle], eax
		call CloseFile

		call UnzipFileRec

		jmp .done
	.dir:
		mov esi, outPath
		mov ebx, byteRead
		.cpyDirName:
			call fio_read
			
			push eax
			mov al, [byteRead]
			mov [esi], al
			pop eax

			inc esi ; move to the next byte in the string
			cmp byte [byteRead], byte 0
			jne .cpyDirName
		.doneCpyDirName:


		
		; create the directory
		push dword 0 ; [in, optional] LPSECURITY_ATTRIBUTES lpSecurityAttributes
		push outPath ;  [in] LPCSTR lpPathName,
		call _CreateDirectoryA@8
		call UnzipFileRec
		jc .error
		jmp .done

	.done:
		popa
		clc
		ret
	.error:
		popa
		stc
		ret
UnzipFile: ; unzip a file
	pusha
	mov eax, [readFileHandle]
	; get the type
	mov ecx, 1	; read 1 byte at a time
	mov ebx, byteRead
	call fio_read
	cmp edx, 1	; if edx is 1, end of file
	jne .doneDir
	mov bl, [byteRead]	; move the byte read into bl
	mov [type], bl
	cmp bl, 'd'
	je .dir
	cmp bl, 'f'
	je .file
	jmp .error
	.file:
		mov esi, outPath
		mov ebx, byteRead
		.cpyFileName:
			call fio_read
			
			push eax
			mov al, [byteRead]
			mov [esi], al
			pop eax

			inc esi ; move to the next byte in the string
			cmp byte [byteRead], byte 0
			jne .cpyFileName

		; get the number of bytes
		mov ecx, 4 ; read 4 bytes
		mov ebx, dwordRead
		call fio_read
		cmp edx, 4
		jne .error
		mov ebx, [ebx] ; get the number of bytes
		mov [numLeafs], ebx ; store the number of bytes in the numLeafs variable
		
		call AllocCodes
		jc .error
		call InitCodes
		call ReadCodes

		mov eax, [readFileHandle]
		mov ebx, numBytesWritten
		mov ecx, 4 ; read 4 bytes
		call fio_read
		cmp edx, 4
		jne .error

		; read usefulBits
		mov eax, [readFileHandle]
		mov ebx, usefulBits
		mov ecx, 1 ; read 1 byte
		call fio_read
		cmp edx, 1
		jne .error


		; open the output file
		mov esi, outPath
		mov edi, openPath
		call StrCpy ; copy the path to the openPath variable
		mov [openFileMode], dword 1 ; write mode
		push eax
		call OpenFile
		pop eax
		jc .error
		mov esi, [openFileHandle]
		mov [writeFileHandle], esi

		call WriteDecodedFile
		jc .error
		jmp .doneFile
	.dir:
		mov esi, outPath
		mov ebx, byteRead
		.cpyDirName:
			call fio_read
			
			push eax
			mov al, [byteRead]
			mov [esi], al
			pop eax

			inc esi ; move to the next byte in the string
			cmp byte [byteRead], byte 0
			jne .cpyDirName
		.doneCpyDirName:


		
		; create the directory
		push dword 0 ; [in, optional] LPSECURITY_ATTRIBUTES lpSecurityAttributes
		push outPath ;  [in] LPCSTR lpPathName,
		call _CreateDirectoryA@8
		call UnzipFileRec
		jc .error
		jmp .doneDir

	.doneDir:
		popa
		clc
		ret
	.doneFile:
		; close the write file
		mov eax, [writeFileHandle]
		mov [closeFileHandle], eax
		call CloseFile
		popa
		clc
		ret
	.error:
		popa
		stc
		ret
RestoreCurrentDir: ; basically put a zero byte on the last '\'
pusha
mov esi, currentDir
call StrLen
add esi, eax ; move to the last byte
.dec:
	cmp byte [esi], byte '\'
	je .putZero
	cmp byte [esi], byte '/'
	je .putZero
	cmp esi, currentDir
	je .done
	dec esi
	jmp .dec
.putZero:
	mov byte [esi], byte 0
.done:
	popa
	clc
	ret
ZipInnerDir: ; zip inner dir
pusha
	; modified version of .inDir from main function
	.inDir:
		; write d byte
		mov eax, [writeFileHandle]
		mov [byteRead], byte 'd'
		mov ebx, byteRead
		mov ecx, 1 ; write 1 byte
		call fio_write ; write the byte
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error

		; write the name of the directory
		mov eax, [writeFileHandle]
		mov ebx, currentDir
		mov ecx, 1
		.writeDirName:
			cmp byte [ebx], byte 0 ; if the byte is 0, it's the end of the string
			je .doneWriteDirName
			call fio_write
			cmp edx, 1 ; if edx is not 1, there was an error
			jne .error
			inc ebx ; move to the next byte in the string
			jmp .writeDirName
		.doneWriteDirName:
		; write the zero byte
		call fio_write
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error

		mov esi, currentDir
		mov edi, findFileString
		call StrCpy 
		mov esi, slashstar
		mov edi, findFileString
		call StrCat

		; use windows api to get the files in the directory
		; first two files found are . and ..
		push findData
		push findFileString
    	call _FindFirstFileA@8
		mov [findHandle], eax

		call _GetLastError@0
		; skip ..
		mov eax, [findHandle]
		push findData
		push eax
		call _FindNextFileA@8

		
		.whileFiles:
			mov eax, [findHandle]
			push findData
			push eax
			call _FindNextFileA@8
			
			call _GetLastError@0
			cmp eax, dword 0x12 ; ERROR_NO_MORE_FILES
			je .doneFiles

			; copy file name with path to path variable
			mov edi, path
			mov esi, currentDir
			call StrCpy ; copy the path to the path variable

			; get type from esi + 44
			push eax
			push esi
				mov esi, findData
				add esi, 44 ; move to the file name
				call StrLen
				add esi, eax ; move to the last byte
				.backwards:
					cmp byte [esi], byte '.'
					je .itsAFile
					cmp byte [esi], byte '\'
					je .itsADir
					cmp byte [esi], byte '/'
					je .itsADir
					cmp esi, currentDir
					je .itsADir
					dec esi
					jmp .backwards
				.itsAFile:
					mov [type], byte 'f'
					jmp .doneType
				.itsADir:
					mov [type], byte 'd'
			.doneType:
			pop esi
			pop eax
			cmp [type], byte 'd'
			je .skipDir

			mov esi, currentDir
			mov edi, openPath
			call StrCpy ; copy the path to the openPath variable
			mov edi, openPath
			mov esi, slashString
			call StrCat

			mov esi, findData
			add esi, 44 ; move to the file name
			mov edi, openPath
			call StrCat
			mov [openFileMode], dword 0 ; read mode
			call OpenFile
			jc .error
			mov eax, [openFileHandle]
			mov [readFileHandle], eax
			; call the function to zip file


			; store path in the stack
			nop
			mov edx, eax ; store eax in edx
			mov esi, path
			call StrLen
			inc eax ; include the zero byte
			push esp
			sub esp, eax ; allocate space for the string
			mov edi, esp
			call StrCpy

			nop
			mov edi, path
			mov esi, openPath
			call StrCpy

			call ZipFile
			
			; restore path from the stack
			mov edi, path
			mov esi, esp
			call StrLen
			inc eax ; include the zero byte
			call StrCpy
			add esp, eax ; free the space allocated for the string
			mov eax, edx ; restore eax from edx
			pop esp
			jc .error

			; close the read file
			mov eax, [readFileHandle]
			mov [closeFileHandle], eax
			call CloseFile

			.skipDir:	
			jmp .whileFiles
		.doneFiles:
		; reset errors
		push dword 0
		call _SetLastError@4

		; reset findData
		mov [findData], dword 0
		push findData
		push findFileString
    	call _FindFirstFileA@8
		mov [findHandle], eax
		
		; skip ..
		mov eax, [findHandle]
		push findData
		push eax
		call _FindNextFileA@8
		.whileInnerDirs:
			mov eax, [findHandle]
			push findData
			push eax
			call _FindNextFileA@8
			
			call _GetLastError@0
			cmp eax, dword 0x12 ; ERROR_NO_MORE_FILES
			je .doneInnerDirs


			mov esi, findData
			add esi, 44 ; move to the file name
			mov edi, path
			call StrCpy ; copy the path to the path variable

			call GetType
			cmp byte [type], byte 'f' 
			je .skipFile

			mov esi, slashString
			mov edi, currentDir
			call StrCat

			; currentdirSlashInnerdir
			mov esi, findData
			add esi, 44 ; move to the file name
			call StrCat 

			; store findHandle
			mov eax, [findHandle]
			push eax
			call ZipInnerDir
			pop eax
			jc .error ; if there was an error
			mov [findHandle], eax ; restore findHandle

			; restore currentDir
			call RestoreCurrentDir ; basically cd ..

			.skipFile:
			jmp .whileInnerDirs
		.doneInnerDirs:
			jmp .done
.done:
	popa
	clc
	ret
.error:
	popa
	stc
	ret
main:
	mov [readFileHandle], dword 0
	mov [writeFileHandle], dword 0
	call ReadCommandLineArgs
	jc .errorArgs
	call GetType
	mov al, byte [mode]
	cmp al, 'i'
	je .in
	cmp al, 'o'
	je .out
.in:
	mov al, byte [type]
	cmp al, 'd'
	je .inDir
	cmp al, 'f'
	je .inFile
	.inFile: ; TODO: file opening closing should be moved to this level both when zipping and unzipping
		mov esi, path
		mov edi, inPath
		call StrCpy ; copy the path to the inPath variable
		call SetOutFilePath
		jc .error

		; open the input file
		mov esi, path
		mov edi, openPath
		call StrCpy ; copy the path to the openPath variable
		mov [openFileMode], dword 0 ; read mode
		call OpenFile
		jc .error
		mov eax, [openFileHandle]
		mov [readFileHandle], eax

		; get absolute position in the file
		mov eax, [readFileHandle]
		mov ebx, 1 ; current position
		mov ecx, 0 ; offset
		call fio_seek
		mov [absolutePosition], edx ; store the absolute position in the absolutePosition variable

		; open the output file
		mov esi, outPath
		mov edi, openPath
		call StrCpy ; copy the path to the openPath variable
		mov [openFileMode], dword 1 ; write mode
		call OpenFile
		jc .error
		mov eax, [openFileHandle]
		mov [writeFileHandle], eax

		call ZipFile
		jc .error

		; close the read file
		mov eax, [readFileHandle]
		mov [closeFileHandle], eax
		call CloseFile

		; close the write file
		mov eax, [writeFileHandle]
		mov [closeFileHandle], eax
		call CloseFile

		jmp .done
	.inDir:
		; get the name of the directory
		mov esi, path
		mov edi, nameRootDir
		call StrCpy

		; open the output file
		mov esi, nameRootDir
		mov edi, outPath
		call StrCpy ; copy the path to the outPath variable

		mov esi, zippedOutputExtension
		mov edi, outPath
		call StrCat ; add the extension

		mov esi, outPath
		mov edi, openPath
		call StrCpy ; copy the path to the openPath variable
		mov [openFileMode], dword 1 ; write mode
		call OpenFile
		jc .error
		mov eax, [openFileHandle]
		mov [writeFileHandle], eax

		; write d byte
		mov eax, [writeFileHandle]
		mov [byteRead], byte 'd'
		mov ebx, byteRead
		mov ecx, 1 ; write 1 byte
		call fio_write ; write the byte
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error

		; write the name of the directory
		mov eax, [writeFileHandle]
		mov ebx, nameRootDir
		mov ecx, 1
		.writeDirName:
			cmp byte [ebx], byte 0 ; if the byte is 0, it's the end of the string
			je .doneWriteDirName
			call fio_write
			cmp edx, 1 ; if edx is not 1, there was an error
			jne .error
			inc ebx ; move to the next byte in the string
			jmp .writeDirName
		.doneWriteDirName:
		; write the zero byte
		call fio_write
		cmp edx, 1 ; if edx is not 1, there was an error
		jne .error

		; search string
		; mov esi, rootDir
		; mov edi, findFileString
		; call StrCpy 
		; mov edi, findFileString
		; mov esi, slashString
		; call StrCat
		; !!!! ROOT DIR IS NOT NECESSARY !!!!
		mov esi, path
		mov edi, findFileString
		call StrCat
		mov esi, slashstar
		mov edi, findFileString
		call StrCat

		; set currentDir to the root directory
		mov esi, path
		mov edi, currentDir
		call StrCpy

		; use windows api to get the files in the directory
		; first two files found are . and ..
		push findData
		push findFileString
    	call _FindFirstFileA@8
		mov [findHandle], eax

		call _GetLastError@0
		; skip ..
		mov eax, [findHandle]
		push findData
		push eax
		call _FindNextFileA@8

		
		.whileFiles:
			mov eax, [findHandle]
			push findData
			push eax
			call _FindNextFileA@8
			
			call _GetLastError@0
			cmp eax, dword 0x12 ; ERROR_NO_MORE_FILES
			je .doneFiles

			; copy file name with path to path variable
			mov edi, path
			mov esi, currentDir
			call StrCpy ; copy the path to the path variable

			; currentdir\
			mov edi, currentDir
			mov esi, slashString
			call StrCat

			; currentdir\path
			mov esi, findData
			add esi, 44 ; move to the file name
			mov edi, path
			call StrCat

			call GetType
			cmp [type], byte 'd'
			je .skipDir

			mov esi, currentDir
			mov edi, openPath
			call StrCpy ; copy the path to the openPath variable
			mov edi, openPath
			mov esi, slashString
			call StrCat

			mov esi, findData
			add esi, 44 ; move to the file name
			mov edi, openPath
			call StrCat
			mov [openFileMode], dword 0 ; read mode
			call OpenFile
			jc .error
			mov eax, [openFileHandle]
			mov [readFileHandle], eax
			; call the function to zip file

			call ZipFile
			jc .error

			; close the read file
			mov eax, [readFileHandle]
			mov [closeFileHandle], eax
			call CloseFile

			.skipDir:	

			jmp .whileFiles
		.doneFiles:
		; reset errors
		push dword 0
		call _SetLastError@4

		; reset findData
		mov [findData], dword 0
		push findData
		push findFileString
    	call _FindFirstFileA@8
		mov [findHandle], eax
		
		; skip ..
		mov eax, [findHandle]
		push findData
		push eax
		call _FindNextFileA@8
		.whileInnerDirs:
			mov eax, [findHandle]
			push findData
			push eax
			call _FindNextFileA@8
			
			call _GetLastError@0
			cmp eax, dword 0x12 ; ERROR_NO_MORE_FILES
			je .doneInnerDirs


			mov esi, findData
			add esi, 44 ; move to the file name
			mov edi, path
			call StrCpy ; copy the path to the path variable

			; !!!! ITT RANDOM ELTŰNIK KÓD !!!!
			; p.s. lehet hogy a per karakter miatt
			; p.s. ne legyen per karakter a kommentekben
			call GetType
			cmp byte [type], byte 'f' 
			je .skipFile


			; push ebx
			; mov ebx, slashString
			; mov esi, ebx
			; pop ebx
			mov esi, slashString
			mov edi, currentDir
			call StrCat

			; currentdir\innerdir
			mov esi, findData
			add esi, 44 ; move to the file name
			call StrCat 

			; store findHandle
			mov eax, [findHandle]
			push eax
			call ZipInnerDir
			pop eax
			jc .error ; if there was an error
			mov [findHandle], eax ; restore findHandle

			; restore currentDir
			call RestoreCurrentDir ; basically cd ..

			.skipFile:
			jmp .whileInnerDirs
		.doneInnerDirs:
			jmp .done
.out:
	; open the input file
	mov esi, path
	mov edi, openPath
	call StrCpy ; copy the path to the openPath variable
	mov [openFileMode], dword 0 ; read mode
	call OpenFile
	jc .error
	mov esi, [openFileHandle]
	mov [readFileHandle], esi

	call UnzipFile
	jc .error

	; close the read file
	mov eax, [readFileHandle]
	mov [closeFileHandle], eax
	call CloseFile

	; ; close the write file
	; mov eax, [writeFileHandle]
	; mov [closeFileHandle], eax
	; call CloseFile

	ret
.error:
.errorArgs:
	mov eax, errorArgs
	call io_writestr
	call io_writeln
	mov eax, usage
	call io_writestr
	
	ret
.done:
	ret
	
; variables
section .bss
	openFileHandle resd 1 ; 1 dword (file handle)
	closeFileHandle resd 1 ; 1 dword (file handle)
	readFileHandle resd 1 ; 1 dword (file handle)
	writeFileHandle resd 1 ; 1 dword (file handle)
	openFileMode resd 1 ; 1 dword (0 = read, 1 = write)
	firstNotNullIndex resd 1 ; 1 dword (index)
	tree resd 1 ; 1 dword (pointer)
	node1 resd 1 ; 1 dword (pointer)
	node2 resd 1 ; 1 dword (pointer)
	node1Index resd 1 ; 1 dword (index)
	node2Index resd 1 ; 1 dword (index)
	freeNode resd 1 ; 1 dword (pointer)
	counts resb 1285 ; (1+4)*257 = 1285 (bytes)
	codes resd 1 ; 1 dword (pointer) 
	byteCodePtr1 resd 1 ; 1 dword (pointer)
	byteCodePtr2 resd 1 ; 1 dword (pointer)
	numNodes resd 1 ; 1 dword
	numInternalNodes resd 1 ; 1 dword
	numSearchNodes resd 1 ; 1 dword
	numLeafs resd 1 ; 1 dword
	openPath resb 256 ; 256 bytes
	path resb 256 ; 256 bytes
	inPath resb 256 ; 256 bytes
	outPath resb 256 ; 256 bytes
	mode resb 1 ; 1 byte
	type resb 1 ; 1 byte
	byteRead resb 1 ; 1 byte
	dwordRead resd 1 ; 1 dword
	debugDword resd 1 ; 1 dword
	debugByte resb 1 ; 1 byte
	byteCode resd 1 ; 1 dword
	codeString resb 9 ; 9 bytes
	codeStringByte resb 1 ; 1 byte
	codeStringLen resb 1 ; 1 byte
	usefulBits resb 1 ; 1 byte
	absolutePosition resd 1 ; 1 dword
	decodeCode resb 256 ; 256 bytes
	findFileString resb 256 ; 256 bytes
	rootDir resb 256 ; 256 bytes
	findData resb 512 ; 448 bytes
	findHandle resd 1 ; 1 dword
	numBytesWritten resd 1 ; 1 dword
	nameRootDir resb 256 ; 256 bytes
	currentDir resb 256 ; 256 bytes

section .data
	errorArgs db "Invalid arguments", 0
	usage db "Usage: |executable| |path| |mode|", 0
	delimiter db 0x1C
	slashstar db "\*", 0
	slashString db "\", 0
	debugOutPath db "ki.in", 0
	zippedOutputExtension db ".bin", 0
