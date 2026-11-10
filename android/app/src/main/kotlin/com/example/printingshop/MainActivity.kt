package com.example.printingshop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PageRange
import android.print.PrintManager
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "printingshop/job_ticket").setMethodCallHandler { call, result ->
            if (call.method != "print") { result.notImplemented(); return@setMethodCallHandler }
            val title = call.argument<String>("title") ?: "Production Job Ticket"
            val lines = call.argument<List<String>>("lines") ?: emptyList()
            try {
                val manager = getSystemService(Context.PRINT_SERVICE) as PrintManager
                manager.print(title, TicketAdapter(title, lines), PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).build())
                result.success(null)
            } catch (e: Exception) { result.error("PRINT_FAILED", e.message, null) }
        }
    }
}

private class TicketAdapter(private val title: String, lines: List<String>) : PrintDocumentAdapter() {
    // Wrap long notes and requirements; never silently truncate a ticket.
    private val content = (listOf("KCZ PRINTING SHOP", title, "") + lines).flatMap { line ->
        line.split('\n').flatMap { if (it.isEmpty()) listOf("") else it.chunked(75) }
    }
    private val pages get() = maxOf(1, (content.size + 44) / 45)
    override fun onLayout(oldAttributes: PrintAttributes?, newAttributes: PrintAttributes?, cancellationSignal: CancellationSignal?, callback: LayoutResultCallback, extras: Bundle?) {
        if (cancellationSignal?.isCanceled == true) { callback.onLayoutCancelled(); return }
        callback.onLayoutFinished(PrintDocumentInfo.Builder("$title.pdf").setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT).setPageCount(pages).build(), true)
    }
    override fun onWrite(ranges: Array<out PageRange>, destination: ParcelFileDescriptor, cancellationSignal: CancellationSignal, callback: WriteResultCallback) {
        val pdf = PdfDocument()
        try {
            val written = mutableListOf<PageRange>()
            for (pageIndex in 0 until pages) {
                if (cancellationSignal.isCanceled) { callback.onWriteCancelled(); return }
                if (ranges.none { pageIndex >= it.start && pageIndex <= it.end }) continue
                val page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageIndex + 1).create())
                val paint = Paint().apply { textSize = 11f; isAntiAlias = true }
                content.drop(pageIndex * 45).take(45).forEachIndexed { index, line -> page.canvas.drawText(line, 40f, 45f + index * 16f, paint) }
                pdf.finishPage(page)
                written.add(PageRange(pageIndex, pageIndex))
            }
            FileOutputStream(destination.fileDescriptor).use { pdf.writeTo(it) }
            callback.onWriteFinished(written.toTypedArray())
        } catch (e: Exception) { callback.onWriteFailed(e.message) }
        finally { pdf.close() }
    }
}
